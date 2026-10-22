import Foundation
import UniformTypeIdentifiers

/// Supported output formats in DropLabCore.
public enum TargetFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    // Audio
    case wav
    case caf
    case m4a
    case aiff

    // Image
    case png
    case jpg
    case heic
    case tiff
    case gif
    case icns

    // Video
    case mp4
    case mov

    // Document / Data
    case pdf
    case json
    case plist
    case csv
    case tsv

    public var id: String { rawValue }

    public var label: String {
        rawValue.uppercased()
    }

    public var fileExtension: String {
        rawValue
    }

    public var category: FileCategory {
        switch self {
        case .wav, .caf, .m4a, .aiff:
            return .audio
        case .png, .jpg, .heic, .tiff, .gif, .icns:
            return .image
        case .mp4, .mov:
            return .video
        case .pdf:
            return .document
        case .json, .plist, .csv, .tsv:
            return .data
        }
    }

    public var systemSymbolName: String {
        switch self {
        case .wav, .caf, .m4a, .aiff:
            return "waveform"
        case .png, .jpg, .heic, .tiff, .gif:
            return "photo"
        case .icns:
            return "app.dashed"
        case .mp4, .mov:
            return "film"
        case .pdf:
            return "doc.richtext"
        case .json, .plist:
            return "curlybraces"
        case .csv, .tsv:
            return "tablecells"
        }
    }
}
