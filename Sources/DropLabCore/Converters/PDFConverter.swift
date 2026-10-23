import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PDFKit

/// Native PDF multi-tool built on PDFKit (Merge PDFs/Images into 1 PDF, Split PDF pages, or Smart PDF Compression).
public struct PDFConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        guard let doc = PDFDocument(url: sourceURL) else {
            throw DropLabError.readerInitializationFailed("Cannot open PDF \(sourceURL.lastPathComponent)")
        }

        if options.preset == .compressPDF {
            try writeCompressedPDF(doc, to: outputURL)
            return
        }

        if options.preset == .splitPages && doc.pageCount > 1 {
            // Write page 1 to `outputURL` and remaining pages next to it
            let baseDir = outputURL.deletingLastPathComponent()
            let baseStem = sourceURL.deletingPathExtension().lastPathComponent
            for idx in 0..<doc.pageCount {
                guard let page = doc.page(at: idx) else { continue }
                let singleDoc = PDFDocument()
                singleDoc.insert(page, at: 0)
                let targetURL: URL
                if idx == 0 {
                    targetURL = outputURL
                } else {
                    targetURL = baseDir.appendingPathComponent("\(baseStem)_page\(idx + 1).pdf")
                }
                singleDoc.write(to: targetURL)
            }
            return
        }

        guard doc.write(to: outputURL) else {
            throw DropLabError.conversionFailed("Failed to write PDF output")
        }
    }

    /// Merges multiple PDFs and/or Images into a single combined PDF document.
    public func mergeFiles(_ urls: [URL], to outputURL: URL) throws {
        let combined = PDFDocument()
        var insertIndex = 0

        for url in urls {
            if url.pathExtension.lowercased() == "pdf",
               let srcPDF = PDFDocument(url: url) {
                for p in 0..<srcPDF.pageCount {
                    if let page = srcPDF.page(at: p) {
                        combined.insert(page, at: insertIndex)
                        insertIndex += 1
                    }
                }
            } else if let nsImage = NSImage(contentsOf: url),
                      let page = PDFPage(image: nsImage) {
                combined.insert(page, at: insertIndex)
                insertIndex += 1
            }
        }

        guard combined.pageCount > 0, combined.write(to: outputURL) else {
            throw DropLabError.conversionFailed("Failed to merge files into PDF")
        }
    }

    private func writeCompressedPDF(_ doc: PDFDocument, to outputURL: URL) throws {
        let compressedDoc = PDFDocument()
        let renderScale: CGFloat = 1.25 // ~90-120 DPI compact web/email optimization
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for idx in 0..<doc.pageCount {
            guard let page = doc.page(at: idx) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = max(1, Int(bounds.width * renderScale))
            let height = max(1, Int(bounds.height * renderScale))

            guard let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }

            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.scaleBy(x: renderScale, y: renderScale)
            page.draw(with: .mediaBox, to: ctx)

            guard let rawCG = ctx.makeImage() else { continue }

            // Re-encode page bitmap as lossy JPEG (0.68 quality) to shrink embedded scan/image payloads
            let jpegData = NSMutableData()
            if let dest = CGImageDestinationCreateWithData(jpegData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) {
                let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.68]
                CGImageDestinationAddImage(dest, rawCG, props as CFDictionary)
                if CGImageDestinationFinalize(dest),
                   let nsImg = NSImage(data: jpegData as Data),
                   let newPage = PDFPage(image: nsImg) {
                    newPage.setBounds(bounds, for: .mediaBox)
                    compressedDoc.insert(newPage, at: compressedDoc.pageCount)
                }
            }
        }

        let targetDoc = compressedDoc.pageCount > 0 ? compressedDoc : doc
        guard targetDoc.write(to: outputURL) else {
            throw DropLabError.conversionFailed("Failed to write compressed PDF")
        }
    }
}
