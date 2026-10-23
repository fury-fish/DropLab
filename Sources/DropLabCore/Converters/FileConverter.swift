import Foundation

public enum DropLabError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case unsupportedInput(URL)
    case unsupportedConversion(from: String, to: TargetFormat)
    case readerInitializationFailed(String)
    case writerInitializationFailed(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Không tìm thấy file: \(url.lastPathComponent)"
        case .permissionDenied(let url):
            let folder = url.deletingLastPathComponent().lastPathComponent
            return "Không có quyền đọc file '\(url.lastPathComponent)' trong '\(folder)'. Hãy mở DropLab.app trực tiếp từ /Applications."
        case .unsupportedInput(let url):
            return "Định dạng đầu vào chưa hỗ trợ: \(url.lastPathComponent)"
        case .unsupportedConversion(let from, let to):
            return "Chưa hỗ trợ chuyển từ .\(from) sang .\(to.rawValue)"
        case .readerInitializationFailed(let detail):
            return "Không đọc được dữ liệu media: \(detail)"
        case .writerInitializationFailed(let detail):
            return "Không tạo được file xuất: \(detail)"
        case .conversionFailed(let detail):
            return "Lỗi chuyển đổi: \(detail)"
        }
    }
}

public protocol FileConverter: Sendable {
    func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws
}
