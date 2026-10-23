import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Packs one or multiple images into a grid `spritesheet.png` and emits a companion `spritesheet.json` atlas metadata file.
public enum SpriteSheetGenerator {
    public static func generateSpriteSheet(from urls: [URL], to outputPNGURL: URL) throws {
        var frames: [(name: String, image: CGImage)] = []

        for url in urls {
            let resolved = (url as NSURL).filePathURL ?? url
            let hasScope = resolved.startAccessingSecurityScopedResource()
            defer {
                if hasScope {
                    resolved.stopAccessingSecurityScopedResource()
                }
            }

            if let data = try? Data(contentsOf: resolved),
               let src = CGImageSourceCreateWithData(data as CFData, nil),
               let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                frames.append((resolved.lastPathComponent, cg))
            } else if let nsImg = NSImage(contentsOf: resolved),
                      var rect = Optional(CGRect(origin: .zero, size: nsImg.size)),
                      let cg = nsImg.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                frames.append((resolved.lastPathComponent, cg))
            }
        }

        guard !frames.isEmpty else {
            throw DropLabError.readerInitializationFailed("No valid images found for SpriteSheet generation")
        }

        let cellWidth = frames.map(\.image.width).max() ?? 64
        let cellHeight = frames.map(\.image.height).max() ?? 64
        let columns = max(1, Int(ceil(sqrt(Double(frames.count)))))
        let rows = max(1, Int(ceil(Double(frames.count) / Double(columns))))
        let sheetWidth = columns * cellWidth
        let sheetHeight = rows * cellHeight

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: sheetWidth,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw DropLabError.conversionFailed("Failed to allocate SpriteSheet bitmap context")
        }

        ctx.interpolationQuality = .high
        var atlasFrames: [[String: Any]] = []

        for (index, item) in frames.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = col * cellWidth
            // Top-to-bottom row ordering in atlas coordinates; CoreGraphics origin is bottom-left
            let yTopDown = row * cellHeight
            let cgY = sheetHeight - yTopDown - item.image.height

            ctx.draw(
                item.image,
                in: CGRect(x: x, y: cgY, width: item.image.width, height: item.image.height)
            )

            atlasFrames.append([
                "filename": item.name,
                "index": index,
                "frame": [
                    "x": x,
                    "y": yTopDown,
                    "w": item.image.width,
                    "h": item.image.height
                ]
            ])
        }

        guard let sheetImage = ctx.makeImage() else {
            throw DropLabError.conversionFailed("Failed to render SpriteSheet CGImage")
        }

        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            outData as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw DropLabError.writerInitializationFailed("Cannot create PNG destination for SpriteSheet")
        }
        CGImageDestinationAddImage(dest, sheetImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw DropLabError.conversionFailed("Failed to finalize SpriteSheet PNG")
        }
        try (outData as Data).write(to: outputPNGURL, options: .atomic)

        // Write companion JSON atlas metadata next to the PNG
        let jsonURL = outputPNGURL.deletingPathExtension().appendingPathExtension("json")
        let metadata: [String: Any] = [
            "meta": [
                "app": "DropLab",
                "image": outputPNGURL.lastPathComponent,
                "size": ["w": sheetWidth, "h": sheetHeight],
                "cellSize": ["w": cellWidth, "h": cellHeight],
                "columns": columns,
                "rows": rows,
                "frameCount": frames.count
            ],
            "frames": atlasFrames
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: jsonURL, options: .atomic)
        }
    }
}
