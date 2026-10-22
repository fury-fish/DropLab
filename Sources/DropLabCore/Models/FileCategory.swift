import Foundation
import UniformTypeIdentifiers

/// High-level media/file category used by DropLab to filter compatible target formats.
public enum FileCategory: String, Codable, CaseIterable, Sendable {
    case audio
    case image
    case video
    case document
    case data
    case unknown

    public var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .image: return "Image"
        case .video: return "Video"
        case .document: return "Document"
        case .data: return "Data & Config"
        case .unknown: return "Unknown"
        }
    }

    public var systemSymbolName: String {
        switch self {
        case .audio: return "waveform"
        case .image: return "photo"
        case .video: return "film"
        case .document: return "doc.richtext"
        case .data: return "curlybraces"
        case .unknown: return "questionmark.folder"
        }
    }

    /// Detects the `FileCategory` of a file URL using `UniformTypeIdentifiers` (`UTType`).
    public static func detect(for url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return .unknown }

        // Explicit fast path for common extensions
        switch ext {
        case "mp3", "wav", "wave", "m4a", "aac", "caf", "aiff", "aif", "flac", "ogg", "opus":
            return .audio
        case "png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "webp", "avif", "icns", "bmp", "svg":
            return .image
        case "mp4", "mov", "m4v", "webm", "mkv", "avi":
            return .video
        case "pdf":
            return .document
        case "json", "plist", "csv", "tsv", "xml", "yaml", "yml":
            return .data
        default:
            break
        }

        if let utType = UTType(filenameExtension: ext) {
            if utType.conforms(to: .audio) { return .audio }
            if utType.conforms(to: .image) { return .image }
            if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
            if utType.conforms(to: .pdf) { return .document }
            if utType.conforms(to: .json) || utType.conforms(to: .propertyList) || utType.conforms(to: .commaSeparatedText) {
                return .data
            }
        }

        return .unknown
    }
}
