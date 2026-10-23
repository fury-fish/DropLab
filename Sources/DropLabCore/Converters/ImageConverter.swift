import Foundation
import AppKit
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import PDFKit

/// Native hardware-accelerated Image & Icon converter built on ImageIO, CoreImage & CoreGraphics.
public struct ImageConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let resolvedSource = (sourceURL as NSURL).filePathURL ?? sourceURL
        let hasScope = resolvedSource.startAccessingSecurityScopedResource()
        defer {
            if hasScope {
                resolvedSource.stopAccessingSecurityScopedResource()
            }
        }

        let baseImage = try loadCGImage(from: resolvedSource)

        let scaleFactor: CGFloat
        switch options.preset {
        case .scale2x: scaleFactor = 2.0
        case .scale05x: scaleFactor = 0.5
        default: scaleFactor = 1.0
        }

        let flattenAlpha = (options.preset == .removeAlpha) || (options.targetFormat == .jpg)
        let processedImage = try transformImage(
            baseImage,
            scale: scaleFactor,
            removeAlpha: flattenAlpha
        )

        if options.targetFormat == .pdf {
            try writeImageAsPDF(processedImage, to: outputURL)
            return
        }

        if options.targetFormat == .icns {
            try writeICNS(from: processedImage, to: outputURL)
            return
        }

        let destinationTypeIdentifier = try utTypeIdentifier(for: options.targetFormat)
        let outData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outData as CFMutableData,
            destinationTypeIdentifier as CFString,
            1,
            nil
        ) else {
            throw DropLabError.writerInitializationFailed("CGImageDestination failed for \(options.targetFormat.rawValue)")
        }

        var properties: [CFString: Any] = [:]
        if options.targetFormat == .jpg || options.targetFormat == .heic {
            let quality: Double = (options.preset == .quality80) ? 0.80 : 0.92
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        if flattenAlpha {
            properties[kCGImageDestinationBackgroundColor] = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }

        CGImageDestinationAddImage(destination, processedImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw DropLabError.conversionFailed("Failed to encode image to .\(options.targetFormat.rawValue)")
        }

        do {
            try (outData as Data).write(to: outputURL, options: .atomic)
        } catch {
            throw DropLabError.writerInitializationFailed(error.localizedDescription)
        }
    }

    private func loadCGImage(from url: URL) throws -> CGImage {
        // Verify read access explicitly so sandbox / TCC permission errors are reported clearly
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch let nsError as NSError {
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                throw DropLabError.permissionDenied(url)
            }
            if nsError.domain == NSPOSIXErrorDomain && (nsError.code == Int(EPERM) || nsError.code == Int(EACCES)) {
                throw DropLabError.permissionDenied(url)
            }
            throw DropLabError.readerInitializationFailed(nsError.localizedDescription)
        }

        // 1. PDF first-page rasterizer
        if url.pathExtension.lowercased() == "pdf",
           let pdfDoc = PDFDocument(data: fileData),
           let firstPage = pdfDoc.page(at: 0) {
            let pageRect = firstPage.bounds(for: .mediaBox)
            let renderScale: CGFloat = 2.0
            let width = max(1, Int(pageRect.width * renderScale))
            let height = max(1, Int(pageRect.height * renderScale))
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
                ctx.scaleBy(x: renderScale, y: renderScale)
                firstPage.draw(with: .mediaBox, to: ctx)
                if let rendered = ctx.makeImage() {
                    return rendered
                }
            }
        }

        // 2. Primary ImageIO decoder from Data (auto-applies EXIF orientation via thumbnail/options if needed)
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: true]
        if let source = CGImageSourceCreateWithData(fileData as CFData, sourceOptions as CFDictionary),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions as CFDictionary) {
            return cgImage
        }

        // 3. CoreImage fallback (handles CMYK JPEGs, HDR gain-map JPEGs, WebP/AVIF misnamed as .JPG, RAW)
        if let ciImage = CIImage(data: fileData, options: [.applyOrientationProperty: true]) {
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                return cgImage
            }
        }

        // 4. AppKit NSImage fallback (handles SVG vectors, EPS, ICNS)
        if let nsImage = NSImage(data: fileData) ?? NSImage(contentsOf: url) {
            var rect = CGRect(
                x: 0,
                y: 0,
                width: max(64, nsImage.size.width),
                height: max(64, nsImage.size.height)
            )
            if let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                return cgImage
            }
        }

        throw DropLabError.readerInitializationFailed("Cannot decode image from \(url.lastPathComponent)")
    }

    private func transformImage(
        _ image: CGImage,
        scale: CGFloat,
        removeAlpha: Bool
    ) throws -> CGImage {
        let targetWidth = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(image.height) * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = removeAlpha
            ? CGImageAlphaInfo.noneSkipLast.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw DropLabError.conversionFailed("Failed to allocate CoreGraphics bitmap context")
        }

        let rect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        if removeAlpha {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
        }
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        guard let result = context.makeImage() else {
            throw DropLabError.conversionFailed("Failed to extract transformed CGImage")
        }
        return result
    }

    private func writeICNS(from image: CGImage, to outputURL: URL) throws {
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        let outData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outData as CFMutableData,
            "com.apple.icns" as CFString,
            sizes.count,
            nil
        ) else {
            throw DropLabError.writerInitializationFailed("Cannot create ICNS destination")
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        for dim in sizes {
            guard let ctx = CGContext(
                data: nil,
                width: dim,
                height: dim,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: dim, height: dim))
            if let resized = ctx.makeImage() {
                CGImageDestinationAddImage(destination, resized, nil)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw DropLabError.conversionFailed("Failed to finalize .icns file")
        }
        try (outData as Data).write(to: outputURL, options: .atomic)
    }

    private func writeImageAsPDF(_ image: CGImage, to outputURL: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let outData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DropLabError.writerInitializationFailed("Cannot create PDF context")
        }
        pdfContext.beginPDFPage(nil)
        pdfContext.draw(image, in: mediaBox)
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        try (outData as Data).write(to: outputURL, options: .atomic)
    }

    private func utTypeIdentifier(for format: TargetFormat) throws -> String {
        switch format {
        case .png: return UTType.png.identifier
        case .jpg: return UTType.jpeg.identifier
        case .heic: return UTType.heic.identifier
        case .tiff: return UTType.tiff.identifier
        case .gif: return UTType.gif.identifier
        case .icns: return "com.apple.icns"
        default:
            throw DropLabError.unsupportedConversion(from: "image", to: format)
        }
    }
}
