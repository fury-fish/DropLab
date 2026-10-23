import Foundation
import AppKit
import CoreGraphics
import Vision

/// Converts an `.svg` vector file or raster image contour into a ready-to-use SwiftUI `Shape` `.swift` file.
public struct SwiftShapeConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let resolvedSource = (sourceURL as NSURL).filePathURL ?? sourceURL
        let hasScope = resolvedSource.startAccessingSecurityScopedResource()
        defer {
            if hasScope {
                resolvedSource.stopAccessingSecurityScopedResource()
            }
        }

        let rawStem = resolvedSource.deletingPathExtension().lastPathComponent
        let structName = sanitizeIdentifier(rawStem) + "Shape"

        let swiftSource: String
        if resolvedSource.pathExtension.lowercased() == "svg",
           let svgText = try? String(contentsOf: resolvedSource, encoding: .utf8) {
            swiftSource = generateSwiftShapeFromSVG(svgText, structName: structName)
        } else {
            swiftSource = try generateSwiftShapeFromRasterContour(resolvedSource, structName: structName)
        }

        do {
            try swiftSource.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            throw DropLabError.writerInitializationFailed(error.localizedDescription)
        }
    }

    private func sanitizeIdentifier(_ raw: String) -> String {
        let cleaned = raw.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        guard let first = cleaned.first else { return "Custom" }
        if first.isNumber {
            return "Icon" + cleaned
        }
        return first.uppercased() + cleaned.dropFirst()
    }

    private func generateSwiftShapeFromSVG(_ svg: String, structName: String) -> String {
        let (viewW, viewH) = parseViewBox(from: svg)
        var statements: [String] = []

        // Parse simple <path d="M ... L ... Z" /> commands
        let pathRegex = try? NSRegularExpression(pattern: #"<path[^>]*\bd\s*=\s*"([^"]+)"#, options: [.caseInsensitive])
        let nsSVG = svg as NSString
        let matches = pathRegex?.matches(in: svg, range: NSRange(location: 0, length: nsSVG.length)) ?? []

        for match in matches {
            if match.numberOfRanges > 1 {
                let dString = nsSVG.substring(with: match.range(at: 1))
                statements.append(contentsOf: convertSVGPathData(dString, viewWidth: viewW, viewHeight: viewH))
            }
        }

        // Parse <circle cx="..." cy="..." r="..." />
        if let circleRegex = try? NSRegularExpression(pattern: #"<circle[^>]*>"#, options: [.caseInsensitive]) {
            for match in circleRegex.matches(in: svg, range: NSRange(location: 0, length: nsSVG.length)) {
                let tag = nsSVG.substring(with: match.range)
                let cx = extractNumericAttribute("cx", in: tag) ?? (viewW * 0.5)
                let cy = extractNumericAttribute("cy", in: tag) ?? (viewH * 0.5)
                let r = extractNumericAttribute("r", in: tag) ?? (min(viewW, viewH) * 0.25)
                let nx = String(format: "%.4f", (cx - r) / viewW)
                let ny = String(format: "%.4f", (cy - r) / viewH)
                let nw = String(format: "%.4f", (r * 2) / viewW)
                let nh = String(format: "%.4f", (r * 2) / viewH)
                statements.append("        path.addEllipse(in: CGRect(x: rect.minX + \(nx) * w, y: rect.minY + \(ny) * h, width: \(nw) * w, height: \(nh) * h))")
            }
        }

        // Parse <rect x="..." y="..." width="..." height="..." />
        if let rectRegex = try? NSRegularExpression(pattern: #"<rect[^>]*>"#, options: [.caseInsensitive]) {
            for match in rectRegex.matches(in: svg, range: NSRange(location: 0, length: nsSVG.length)) {
                let tag = nsSVG.substring(with: match.range)
                let rx = extractNumericAttribute("x", in: tag) ?? 0
                let ry = extractNumericAttribute("y", in: tag) ?? 0
                let rw = extractNumericAttribute("width", in: tag) ?? viewW
                let rh = extractNumericAttribute("height", in: tag) ?? viewH
                let nx = String(format: "%.4f", rx / viewW)
                let ny = String(format: "%.4f", ry / viewH)
                let nw = String(format: "%.4f", rw / viewW)
                let nh = String(format: "%.4f", rh / viewH)
                statements.append("        path.addRect(CGRect(x: rect.minX + \(nx) * w, y: rect.minY + \(ny) * h, width: \(nw) * w, height: \(nh) * h))")
            }
        }

        if statements.isEmpty {
            statements = [
                "        path.addRoundedRect(in: rect.insetBy(dx: w * 0.08, dy: h * 0.08), cornerSize: CGSize(width: w * 0.16, height: h * 0.16))"
            ]
        }

        return wrapSwiftShapeFile(structName: structName, statements: statements)
    }

    private func generateSwiftShapeFromRasterContour(_ url: URL, structName: String) throws -> String {
        guard let nsImage = NSImage(contentsOf: url),
              var rect = Optional(CGRect(origin: .zero, size: nsImage.size)),
              let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw DropLabError.readerInitializationFailed("Cannot load image for contour extraction: \(url.lastPathComponent)")
        }

        var statements: [String] = []
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.6
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        if (try? handler.perform([request])) != nil,
           let observation = request.results?.first {
            let topContours = observation.topLevelContours.prefix(4)
            for contour in topContours {
                let pts = contour.normalizedPoints
                guard pts.count >= 3 else { continue }
                let step = max(1, pts.count / 24)
                for (idx, ptIdx) in stride(from: 0, to: pts.count, by: step).enumerated() {
                    let pt = pts[ptIdx]
                    let nx = String(format: "%.4f", Double(pt.x))
                    // Vision normalized Y is bottom-up; flip for SwiftUI top-down
                    let ny = String(format: "%.4f", Double(1.0 - pt.y))
                    if idx == 0 {
                        statements.append("        path.move(to: CGPoint(x: rect.minX + \(nx) * w, y: rect.minY + \(ny) * h))")
                    } else {
                        statements.append("        path.addLine(to: CGPoint(x: rect.minX + \(nx) * w, y: rect.minY + \(ny) * h))")
                    }
                }
                statements.append("        path.closeSubpath()")
            }
        }

        if statements.isEmpty {
            statements = [
                "        path.move(to: CGPoint(x: rect.minX + 0.5000 * w, y: rect.minY + 0.0800 * h))",
                "        path.addLine(to: CGPoint(x: rect.minX + 0.9200 * w, y: rect.minY + 0.8800 * h))",
                "        path.addLine(to: CGPoint(x: rect.minX + 0.0800 * w, y: rect.minY + 0.8800 * h))",
                "        path.closeSubpath()"
            ]
        }

        return wrapSwiftShapeFile(structName: structName, statements: statements)
    }

    private func parseViewBox(from svg: String) -> (Double, Double) {
        if let regex = try? NSRegularExpression(pattern: #"viewBox\s*=\s*"([^"]+)"#, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: svg, range: NSRange(location: 0, length: (svg as NSString).length)),
           match.numberOfRanges > 1 {
            let boxStr = (svg as NSString).substring(with: match.range(at: 1))
            let nums = boxStr
                .components(separatedBy: CharacterSet(charactersIn: " ,"))
                .compactMap { Double($0) }
            if nums.count == 4, nums[2] > 0, nums[3] > 0 {
                return (nums[2], nums[3])
            }
        }
        let w = extractNumericAttribute("width", in: svg) ?? 100.0
        let h = extractNumericAttribute("height", in: svg) ?? 100.0
        return (max(1.0, w), max(1.0, h))
    }

    private func extractNumericAttribute(_ name: String, in tag: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: "\\b\(name)\\s*=\\s*\"([0-9.]+)", options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              match.numberOfRanges > 1 else {
            return nil
        }
        return Double((tag as NSString).substring(with: match.range(at: 1)))
    }

    private func convertSVGPathData(_ d: String, viewWidth: Double, viewHeight: Double) -> [String] {
        guard let tokenRegex = try? NSRegularExpression(pattern: #"[MmLlHhVvCcZz]|-?\d*\.?\d+"#) else { return [] }
        let nsD = d as NSString
        let tokens = tokenRegex.matches(in: d, range: NSRange(location: 0, length: nsD.length)).map {
            nsD.substring(with: $0.range)
        }

        var lines: [String] = []
        var i = 0
        var curX = 0.0
        var curY = 0.0
        var cmd = "M"

        func normX(_ x: Double) -> String { String(format: "%.4f", x / viewWidth) }
        func normY(_ y: Double) -> String { String(format: "%.4f", y / viewHeight) }

        while i < tokens.count {
            let tok = tokens[i]
            if tok.rangeOfCharacter(from: CharacterSet.letters) != nil {
                cmd = tok
                i += 1
                if cmd == "Z" || cmd == "z" {
                    lines.append("        path.closeSubpath()")
                }
                continue
            }

            switch cmd {
            case "M":
                guard i + 1 < tokens.count, let x = Double(tokens[i]), let y = Double(tokens[i + 1]) else { i += 1; continue }
                curX = x; curY = y
                lines.append("        path.move(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                cmd = "L"
                i += 2
            case "m":
                guard i + 1 < tokens.count, let dx = Double(tokens[i]), let dy = Double(tokens[i + 1]) else { i += 1; continue }
                curX += dx; curY += dy
                lines.append("        path.move(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                cmd = "l"
                i += 2
            case "L":
                guard i + 1 < tokens.count, let x = Double(tokens[i]), let y = Double(tokens[i + 1]) else { i += 1; continue }
                curX = x; curY = y
                lines.append("        path.addLine(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                i += 2
            case "l":
                guard i + 1 < tokens.count, let dx = Double(tokens[i]), let dy = Double(tokens[i + 1]) else { i += 1; continue }
                curX += dx; curY += dy
                lines.append("        path.addLine(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                i += 2
            case "H":
                guard let x = Double(tokens[i]) else { i += 1; continue }
                curX = x
                lines.append("        path.addLine(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                i += 1
            case "h":
                guard let dx = Double(tokens[i]) else { i += 1; continue }
                curX += dx
                lines.append("        path.addLine(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                i += 1
            case "V":
                guard let y = Double(tokens[i]) else { i += 1; continue }
                curY = y
                lines.append("        path.addLine(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                i += 1
            case "v":
                guard let dy = Double(tokens[i]) else { i += 1; continue }
                curY += dy
                lines.append("        path.addLine(to: CGPoint(x: rect.minX + \(normX(curX)) * w, y: rect.minY + \(normY(curY)) * h))")
                i += 1
            case "C":
                guard i + 5 < tokens.count,
                      let x1 = Double(tokens[i]), let y1 = Double(tokens[i + 1]),
                      let x2 = Double(tokens[i + 2]), let y2 = Double(tokens[i + 3]),
                      let x = Double(tokens[i + 4]), let y = Double(tokens[i + 5]) else { i += 1; continue }
                curX = x; curY = y
                lines.append(
                    "        path.addCurve(to: CGPoint(x: rect.minX + \(normX(x)) * w, y: rect.minY + \(normY(y)) * h), control1: CGPoint(x: rect.minX + \(normX(x1)) * w, y: rect.minY + \(normY(y1)) * h), control2: CGPoint(x: rect.minX + \(normX(x2)) * w, y: rect.minY + \(normY(y2)) * h))"
                )
                i += 6
            default:
                i += 1
            }
        }
        return lines
    }

    private func wrapSwiftShapeFile(structName: String, statements: [String]) -> String {
        let body = statements.joined(separator: "\n")
        return """
        import SwiftUI

        /// Generated by DropLab — SVG / Contour to SwiftUI Shape
        public struct \(structName): Shape {
            public init() {}

            public func path(in rect: CGRect) -> Path {
                var path = Path()
                let w = rect.width
                let h = rect.height
        \(body)
                return path
            }
        }

        #Preview {
            \(structName)()
                .fill(.orange.gradient)
                .frame(width: 180, height: 180)
                .padding()
        }
        """
    }
}
