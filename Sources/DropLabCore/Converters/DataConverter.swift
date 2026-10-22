import Foundation

/// Native Data & Config converter (`json ⟷ plist`, `csv ⟷ tsv`, `csv/tsv ➔ json`).
public struct DataConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let sourceData = try Data(contentsOf: sourceURL)
        let sourceExt = sourceURL.pathExtension.lowercased()

        let object: Any
        switch sourceExt {
        case "json":
            object = try JSONSerialization.jsonObject(with: sourceData, options: [.fragmentsAllowed])
        case "plist":
            object = try PropertyListSerialization.propertyList(from: sourceData, options: [], format: nil)
        case "csv", "tsv":
            let separator: Character = (sourceExt == "tsv") ? "\t" : ","
            let text = String(data: sourceData, encoding: .utf8) ?? ""
            if options.targetFormat == .csv || options.targetFormat == .tsv {
                let targetSeparator = (options.targetFormat == .tsv) ? "\t" : ","
                let converted = convertDelimitedText(text, from: separator, to: targetSeparator)
                try converted.write(to: outputURL, atomically: true, encoding: .utf8)
                return
            }
            object = parseDelimitedToDictionaries(text, separator: separator)
        default:
            throw DropLabError.unsupportedInput(sourceURL)
        }

        switch options.targetFormat {
        case .json:
            var writeOptions: JSONSerialization.WritingOptions = [.sortedKeys]
            if options.preset != .minify {
                writeOptions.insert(.prettyPrinted)
            }
            let outData = try JSONSerialization.data(withJSONObject: object, options: writeOptions)
            try outData.write(to: outputURL, options: .atomic)

        case .plist:
            let plistFormat: PropertyListSerialization.PropertyListFormat =
                (options.preset == .binaryPlist) ? .binary : .xml
            let outData = try PropertyListSerialization.data(
                fromPropertyList: object,
                format: plistFormat,
                options: 0
            )
            try outData.write(to: outputURL, options: .atomic)

        default:
            throw DropLabError.unsupportedConversion(from: sourceExt, to: options.targetFormat)
        }
    }

    private func convertDelimitedText(_ text: String, from: Character, to: String) -> String {
        let lines = text.split(whereSeparator: \.isNewline)
        return lines.map { line in
            line.split(separator: from, omittingEmptySubsequences: false).joined(separator: to)
        }.joined(separator: "\n")
    }

    private func parseDelimitedToDictionaries(_ text: String, separator: Character) -> [[String: String]] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerLine = lines.first else { return [] }
        let headers = headerLine.split(separator: separator, omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return lines.dropFirst().map { row in
            let cols = row.split(separator: separator, omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            var dict: [String: String] = [:]
            for (idx, header) in headers.enumerated() where !header.isEmpty {
                dict[header] = idx < cols.count ? cols[idx] : ""
            }
            return dict
        }
    }
}
