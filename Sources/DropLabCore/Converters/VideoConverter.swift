import Foundation
import AVFoundation
import CoreMedia

/// Native Video converter & trimmer built on AVAssetExportSession & AVMutableComposition.
public struct VideoConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let sourceAsset = AVURLAsset(url: sourceURL)
        let assetDuration = try await sourceAsset.load(.duration)

        let exportAsset: AVAsset
        if options.preset == .muteAudio {
            let composition = AVMutableComposition()
            let videoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
            for track in videoTracks {
                if let compTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    let range = CMTimeRange(start: .zero, duration: assetDuration)
                    try? compTrack.insertTimeRange(range, of: track, at: .zero)
                    if let preferredTransform = try? await track.load(.preferredTransform) {
                        compTrack.preferredTransform = preferredTransform
                    }
                }
            }
            exportAsset = composition
        } else {
            exportAsset = sourceAsset
        }

        guard let exportSession = AVAssetExportSession(
            asset: exportAsset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw DropLabError.writerInitializationFailed("Cannot create AVAssetExportSession")
        }

        let outputFileType: AVFileType
        switch options.targetFormat {
        case .mp4: outputFileType = .mp4
        case .mov: outputFileType = .mov
        default:
            throw DropLabError.unsupportedConversion(from: sourceURL.pathExtension, to: options.targetFormat)
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType
        exportSession.shouldOptimizeForNetworkUse = true

        if let trim = options.effectiveTrimRange {
            let totalSec = CMTimeGetSeconds(assetDuration)
            let clampedStart = min(trim.startSeconds, max(0, totalSec))
            let clampedEnd = totalSec.isFinite && totalSec > 0
                ? min(trim.endSeconds, totalSec)
                : trim.endSeconds
            let durationSec = max(0.05, clampedEnd - clampedStart)
            exportSession.timeRange = CMTimeRange(
                start: CMTime(seconds: clampedStart, preferredTimescale: 600),
                duration: CMTime(seconds: durationSec, preferredTimescale: 600)
            )
        }

        await exportSession.export()
        if exportSession.status != .completed {
            throw DropLabError.conversionFailed(exportSession.error?.localizedDescription ?? "Video export failed")
        }
    }
}
