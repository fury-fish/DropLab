import Foundation

/// Technical modifier / sub-orbit preset that refines how a target format is encoded.
public enum ConversionPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard = "default"

    // Audio presets (Concept 1 Radial Sub-Orbit: LEI16, 24-bit, Cắt / Trim, Mono, ALAC)
    case lei16 = "lei16"
    case pcm24 = "24bit"
    case mono = "mono"
    case trim8s = "trim8s"
    case alac = "alac"

    // Image presets
    case scale2x = "scale2x"
    case scale05x = "scale05x"
    case quality80 = "quality80"
    case removeAlpha = "noalpha"

    // Data presets
    case prettify = "prettify"
    case minify = "minify"
    case binaryPlist = "binary"
    case xmlPlist = "xml"

    public var id: String { rawValue }

    /// Short title displayed inside the Outer Sub-Orbit ring in Radial Orbit UI.
    public var displayTitle: String {
        switch self {
        case .standard: return "Chuẩn"
        case .lei16: return "LEI16"
        case .pcm24: return "24-bit"
        case .mono: return "Mono"
        case .trim8s: return "Cắt 8s"
        case .alac: return "ALAC"
        case .scale2x: return "Scale 2x"
        case .scale05x: return "Scale 0.5x"
        case .quality80: return "80% Qual"
        case .removeAlpha: return "No Alpha"
        case .prettify: return "Prettify"
        case .minify: return "Minify"
        case .binaryPlist: return "Binary"
        case .xmlPlist: return "XML"
        }
    }

    /// Filename suffix appended when a specific non-default preset is chosen (e.g., `match_LEI16.wav`).
    public var filenameSuffix: String? {
        switch self {
        case .standard: return nil
        case .lei16: return "LEI16"
        case .pcm24: return "24bit"
        case .mono: return "mono"
        case .trim8s: return "trim8s"
        case .alac: return "ALAC"
        case .scale2x: return "2x"
        case .scale05x: return "05x"
        case .quality80: return "q80"
        case .removeAlpha: return "opaque"
        case .prettify: return "pretty"
        case .minify: return "min"
        case .binaryPlist: return "bin"
        case .xmlPlist: return "xml"
        }
    }
}
