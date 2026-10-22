import Foundation

public enum DropLabError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case unsupportedInput(URL)
    case unsupportedConversion(from: String, to: TargetFormat)
    case readerInitializationFailed(String)
    case writerInitializationFailed(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .unsupportedInput(let url):
            return "Unsupported input format: \(url.lastPathComponent)"
        case .unsupportedConversion(let from, let to):
            return "Unsupported conversion from .\(from) to .\(to.rawValue)"
        case .readerInitializationFailed(let detail):
            return "Failed to read input media: \(detail)"
        case .writerInitializationFailed(let detail):
            return "Failed to initialize output writer: \(detail)"
        case .conversionFailed(let detail):
            return "Conversion failed: \(detail)"
        }
    }
}

public protocol FileConverter: Sendable {
    func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws
}
