import Foundation

/// Optional time range for audio/video trimming (in seconds).
public struct TimeTrimRange: Codable, Equatable, Sendable {
    public var startSeconds: Double
    public var endSeconds: Double

    public init(startSeconds: Double, endSeconds: Double) {
        self.startSeconds = max(0, startSeconds)
        self.endSeconds = max(self.startSeconds + 0.1, endSeconds)
    }

    public var durationSeconds: Double {
        endSeconds - startSeconds
    }

    /// Default 8-second opening trim (`00:00 - 00:08`) shown in the DropLab concept.
    public static let first8Seconds = TimeTrimRange(startSeconds: 0, endSeconds: 8)
}

/// Options controlling a single or batch conversion.
public struct ConversionOptions: Codable, Equatable, Sendable {
    public var targetFormat: TargetFormat
    public var preset: ConversionPreset
    public var customTrimRange: TimeTrimRange?
    public var outputDirectory: URL?

    public init(
        targetFormat: TargetFormat,
        preset: ConversionPreset = .standard,
        customTrimRange: TimeTrimRange? = nil,
        outputDirectory: URL? = nil
    ) {
        self.targetFormat = targetFormat
        self.preset = preset
        self.customTrimRange = customTrimRange
        self.outputDirectory = outputDirectory
    }

    public var effectiveTrimRange: TimeTrimRange? {
        if let customTrimRange {
            return customTrimRange
        }
        if preset == .trim8s {
            return .first8Seconds
        }
        return nil
    }
}

/// Result of converting a single file.
public struct ConversionResult: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var sourceURL: URL
    public var outputURL: URL
    public var targetFormat: TargetFormat
    public var preset: ConversionPreset
    public var elapsedMilliseconds: Int
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        outputURL: URL,
        targetFormat: TargetFormat,
        preset: ConversionPreset,
        elapsedMilliseconds: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.targetFormat = targetFormat
        self.preset = preset
        self.elapsedMilliseconds = elapsedMilliseconds
        self.timestamp = timestamp
    }
}

/// A Primary Radial Orbit slice + its outer Sub-Orbit presets.
public struct OrbitSliceSpec: Identifiable, Equatable, Sendable {
    public var id: String { targetFormat.rawValue }
    public var targetFormat: TargetFormat
    public var subOrbitPresets: [ConversionPreset]

    public init(targetFormat: TargetFormat, subOrbitPresets: [ConversionPreset]) {
        self.targetFormat = targetFormat
        self.subOrbitPresets = subOrbitPresets
    }
}
