import Foundation
import AVFoundation
import CoreMedia

/// Native Video converter & trimmer built on AVAssetExportSession.
public struct VideoConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let assetDuration = try await asset.load(.duration)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
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
