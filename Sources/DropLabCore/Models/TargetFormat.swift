import Foundation
import UniformTypeIdentifiers

/// Supported output formats in DropLabCore (Native + Extended Codecs).
public enum TargetFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    // Audio
    case wav
    case caf
    case m4a
    case mp3
    case flac
    case ogg
    case aiff

    // Image
    case png
    case jpg
    case webp
    case heic
    case tiff
    case gif
    case icns

    // Video
    case mp4
    case mov
    case webm

    // Document / Data
    case pdf
    case txt
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
        case .wav, .caf, .m4a, .mp3, .flac, .ogg, .aiff:
            return .audio
        case .png, .jpg, .webp, .heic, .tiff, .gif, .icns:
            return .image
        case .mp4, .mov, .webm:
            return .video
        case .pdf, .txt:
            return .document
        case .json, .plist, .csv, .tsv:
            return .data
        }
    }

    public var systemSymbolName: String {
        switch self {
        case .wav, .caf, .m4a, .mp3, .flac, .ogg, .aiff:
            return "waveform"
        case .png, .jpg, .webp, .heic, .tiff, .gif:
            return "photo"
        case .icns:
            return "app.dashed"
        case .mp4, .mov, .webm:
            return "film"
        case .pdf:
            return "doc.richtext"
        case .txt:
            return "doc.text.viewfinder"
        case .json, .plist:
            return "curlybraces"
        case .csv, .tsv:
            return "tablecells"
        }
    }
}
