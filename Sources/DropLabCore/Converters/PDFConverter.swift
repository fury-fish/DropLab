import Foundation
import AppKit
import PDFKit

/// Native PDF multi-tool built on PDFKit (Merge PDFs/Images into 1 PDF, or Split PDF pages).
public struct PDFConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        guard let doc = PDFDocument(url: sourceURL) else {
            throw DropLabError.readerInitializationFailed("Cannot open PDF \(sourceURL.lastPathComponent)")
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
}
