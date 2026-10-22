import Foundation

/// Resolves context-aware Radial Orbit slices and sub-orbit presets for any input file(s).
public struct ConversionRegistry: Sendable {
    public init() {}

    /// Returns the ordered list of Radial Orbit slices (`OrbitSliceSpec`) for a single file URL.
    public func orbitSlices(for url: URL) -> [OrbitSliceSpec] {
        let category = FileCategory.detect(for: url)
        return orbitSlices(for: category, inputExtension: url.pathExtension.lowercased())
    }

    /// Returns the common Radial Orbit slices for a batch of dragged file URLs.
    public func orbitSlices(for urls: [URL]) -> [OrbitSliceSpec] {
        guard let first = urls.first else { return [] }
        let primaryCategory = FileCategory.detect(for: first)
        return orbitSlices(for: primaryCategory, inputExtension: first.pathExtension.lowercased())
    }

    public func orbitSlices(for category: FileCategory, inputExtension: String = "") -> [OrbitSliceSpec] {
        switch category {
        case .audio:
            return [
                OrbitSliceSpec(
                    targetFormat: .wav,
                    subOrbitPresets: [.lei16, .pcm24, .trim8s, .mono]
                ),
                OrbitSliceSpec(
                    targetFormat: .caf,
                    subOrbitPresets: [.lei16, .pcm24, .trim8s, .mono]
                ),
                OrbitSliceSpec(
                    targetFormat: .m4a,
                    subOrbitPresets: [.standard, .alac, .trim8s]
                ),
                OrbitSliceSpec(
                    targetFormat: .mp3,
                    subOrbitPresets: [.standard, .trim8s, .mono]
                ),
                OrbitSliceSpec(
                    targetFormat: .ogg,
                    subOrbitPresets: [.standard, .trim8s, .mono]
                ),
                OrbitSliceSpec(
                    targetFormat: .flac,
                    subOrbitPresets: [.standard, .trim8s, .mono]
                )
            ]

        case .image:
            return [
                OrbitSliceSpec(
                    targetFormat: .png,
                    subOrbitPresets: [.standard, .scale2x, .scale05x, .removeAlpha]
                ),
                OrbitSliceSpec(
                    targetFormat: .webp,
                    subOrbitPresets: [.quality80, .standard, .scale2x, .scale05x]
                ),
                OrbitSliceSpec(
                    targetFormat: .jpg,
                    subOrbitPresets: [.quality80, .standard, .scale2x, .scale05x]
                ),
                OrbitSliceSpec(
                    targetFormat: .heic,
                    subOrbitPresets: [.quality80, .standard, .scale05x]
                ),
                OrbitSliceSpec(
                    targetFormat: .icns,
                    subOrbitPresets: [.standard]
                ),
                OrbitSliceSpec(
                    targetFormat: .pdf,
                    subOrbitPresets: [.standard, .mergePDF]
                )
            ]

        case .video:
            return [
                OrbitSliceSpec(
                    targetFormat: .mp4,
                    subOrbitPresets: [.standard, .trim8s, .muteAudio]
                ),
                OrbitSliceSpec(
                    targetFormat: .mov,
                    subOrbitPresets: [.standard, .trim8s, .muteAudio]
                ),
                OrbitSliceSpec(
                    targetFormat: .gif,
                    subOrbitPresets: [.fps15, .trim8s]
                ),
                OrbitSliceSpec(
                    targetFormat: .webm,
                    subOrbitPresets: [.standard, .trim8s, .muteAudio]
                ),
                OrbitSliceSpec(
                    targetFormat: .wav,
                    subOrbitPresets: [.lei16, .pcm24, .trim8s]
                ),
                OrbitSliceSpec(
                    targetFormat: .m4a,
                    subOrbitPresets: [.standard, .trim8s]
                )
            ]

        case .document:
            return [
                OrbitSliceSpec(
                    targetFormat: .png,
                    subOrbitPresets: [.standard, .scale2x]
                ),
                OrbitSliceSpec(
                    targetFormat: .jpg,
                    subOrbitPresets: [.quality80, .standard]
                ),
                OrbitSliceSpec(
                    targetFormat: .pdf,
                    subOrbitPresets: [.splitPages, .mergePDF]
                )
            ]

        case .data:
            if inputExtension == "csv" || inputExtension == "tsv" {
                return [
                    OrbitSliceSpec(targetFormat: .csv, subOrbitPresets: [.standard]),
                    OrbitSliceSpec(targetFormat: .tsv, subOrbitPresets: [.standard]),
                    OrbitSliceSpec(targetFormat: .json, subOrbitPresets: [.prettify, .minify])
                ]
            }
            return [
                OrbitSliceSpec(
                    targetFormat: .json,
                    subOrbitPresets: [.prettify, .minify]
                ),
                OrbitSliceSpec(
                    targetFormat: .plist,
                    subOrbitPresets: [.xmlPlist, .binaryPlist]
                )
            ]

        case .unknown:
            return []
        }
    }
}
