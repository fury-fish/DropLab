import Foundation
import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import PDFKit

/// On-device Apple Silicon Vision AI processor for OCR text extraction (`VNRecognizeTextRequest`)
/// and AI Subject Background Removal (`VNGenerateForegroundInstanceMaskRequest`).
public struct VisionAIConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let resolvedSource = (sourceURL as NSURL).filePathURL ?? sourceURL
        let hasScope = resolvedSource.startAccessingSecurityScopedResource()
        defer {
            if hasScope {
                resolvedSource.stopAccessingSecurityScopedResource()
            }
        }

        let extractedText = try extractText(from: resolvedSource)
        do {
            try extractedText.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            throw DropLabError.writerInitializationFailed(error.localizedDescription)
        }
    }

    /// Performs on-device OCR on an image or multi-page PDF document.
    public func extractText(from url: URL) throws -> String {
        if url.pathExtension.lowercased() == "pdf",
           let pdfDoc = PDFDocument(url: url),
           pdfDoc.pageCount > 0 {
            var pagesText: [String] = []
            for idx in 0..<pdfDoc.pageCount {
                guard let page = pdfDoc.page(at: idx) else { continue }
                // Combine embedded PDF text layer + Vision OCR if scanned
                let embedded = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !embedded.isEmpty {
                    pagesText.append(pdfDoc.pageCount > 1 ? "--- Page \(idx + 1) ---\n\(embedded)" : embedded)
                } else if let cgImage = renderPDFPage(page) {
                    let ocr = (try? recognizeText(in: cgImage)) ?? ""
                    if !ocr.isEmpty {
                        pagesText.append(pdfDoc.pageCount > 1 ? "--- Page \(idx + 1) ---\n\(ocr)" : ocr)
                    }
                }
            }
            let combined = pagesText.joined(separator: "\n\n")
            return combined.isEmpty ? "[No recognizable text found in \(url.lastPathComponent)]" : combined
        }

        guard let nsImage = NSImage(contentsOf: url),
              var rect = Optional(CGRect(origin: .zero, size: nsImage.size)),
              let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw DropLabError.readerInitializationFailed("Cannot decode image for OCR: \(url.lastPathComponent)")
        }

        let recognized = try recognizeText(in: cgImage)
        return recognized.isEmpty ? "[No recognizable text found in \(url.lastPathComponent)]" : recognized
    }

    /// Isolates the foreground subject and removes the background using macOS 14+ Vision AI (`VNGenerateForegroundInstanceMaskRequest`).
    public static func removeBackground(from cgImage: CGImage) throws -> CGImage {
        let ciInput = CIImage(cgImage: cgImage)
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciInput, options: [:])

        do {
            try handler.perform([request])
            if let observation = request.results?.first,
               !observation.allInstances.isEmpty {
                let maskedBuffer = try observation.generateMaskedImage(
                    ofInstances: observation.allInstances,
                    from: handler,
                    croppedToInstancesExtent: false
                )
                let maskedCI = CIImage(cvPixelBuffer: maskedBuffer)
                let ciContext = CIContext(options: [.useSoftwareRenderer: false])
                if let outputCG = ciContext.createCGImage(maskedCI, from: maskedCI.extent) {
                    return outputCG
                }
            }
        } catch {
            // Fallback below if running in a headless environment without Neural Engine / Vision mask support
        }

        // Fallback corner-sampled background keyer when Vision instance mask is unavailable
        return fallbackRemoveSolidBackground(from: cgImage) ?? cgImage
    }

    private func recognizeText(in cgImage: CGImage) throws -> String {
        if let accurateText = try? performOCR(in: cgImage, level: .accurate) {
            return accurateText
        }
        if let fastText = try? performOCR(in: cgImage, level: .fast) {
            return fastText
        }
        return ""
    }

    private func performOCR(in cgImage: CGImage, level: VNRequestTextRecognitionLevel) throws -> String {
        var recognizedLines: [String] = []
        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            for obs in observations {
                if let top = obs.topCandidates(1).first {
                    recognizedLines.append(top.string)
                }
            }
        }
        request.recognitionLevel = level
        request.usesLanguageCorrection = (level == .accurate)
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return recognizedLines.joined(separator: "\n")
    }

    private func renderPDFPage(_ page: PDFPage) -> CGImage? {
        let rect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let width = max(1, Int(rect.width * scale))
        let height = max(1, Int(rect.height * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }

    private static func fallbackRemoveSolidBackground(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample top-left pixel as reference background color
        let bgR = Int(rawData[0])
        let bgG = Int(rawData[1])
        let bgB = Int(rawData[2])
        let thresholdSq = 38 * 38

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let dr = Int(rawData[i]) - bgR
            let dg = Int(rawData[i + 1]) - bgG
            let db = Int(rawData[i + 2]) - bgB
            if (dr * dr + dg * dg + db * db) <= thresholdSq {
                rawData[i] = 0
                rawData[i + 1] = 0
                rawData[i + 2] = 0
                rawData[i + 3] = 0
            }
        }
        return ctx.makeImage()
    }
}
