import Foundation
import AVFoundation
import CoreMedia

/// Native hardware-accelerated Audio converter & trimmer built on AVAssetReader + AVAssetWriter.
/// Directly replaces `afconvert -f WAVE -d LEI16` and `ffmpeg -ss ... -to ...` workflows.
public struct AudioConverter: FileConverter {
    public init() {}

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let sourceTrack = audioTracks.first else {
            throw DropLabError.readerInitializationFailed("No audio track found in \(sourceURL.lastPathComponent)")
        }

        let assetDuration = try await asset.load(.duration)
        let formatDescriptions = try await sourceTrack.load(.formatDescriptions)

        var sourceSampleRate: Double = 44_100
        var sourceChannels: Int = 2
        if let firstDesc = formatDescriptions.first,
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(firstDesc)?.pointee {
            if asbd.mSampleRate > 0 {
                sourceSampleRate = asbd.mSampleRate
            }
            if asbd.mChannelsPerFrame > 0 {
                sourceChannels = Int(asbd.mChannelsPerFrame)
            }
        }

        let outputChannels = (options.preset == .mono) ? 1 : max(1, min(sourceChannels, 2))
        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sourceSampleRate,
            AVNumberOfChannelsKey: outputChannels,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw DropLabError.readerInitializationFailed(error.localizedDescription)
        }

        if let trim = options.effectiveTrimRange {
            let totalSec = CMTimeGetSeconds(assetDuration)
            let clampedStart = min(trim.startSeconds, max(0, totalSec))
            let clampedEnd = totalSec.isFinite && totalSec > 0
                ? min(trim.endSeconds, totalSec)
                : trim.endSeconds
            let durationSec = max(0.05, clampedEnd - clampedStart)
            reader.timeRange = CMTimeRange(
                start: CMTime(seconds: clampedStart, preferredTimescale: 600),
                duration: CMTime(seconds: durationSec, preferredTimescale: 600)
            )
        }

        let readerOutput = AVAssetReaderTrackOutput(track: sourceTrack, outputSettings: readerOutputSettings)
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else {
            throw DropLabError.readerInitializationFailed("Cannot attach audio track output")
        }
        reader.add(readerOutput)

        let fileType = try avFileType(for: options.targetFormat)
        let writerSettings = try writerOutputSettings(
            for: options.targetFormat,
            preset: options.preset,
            sampleRate: sourceSampleRate,
            channels: outputChannels
        )

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        } catch {
            throw DropLabError.writerInitializationFailed(error.localizedDescription)
        }

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
        writerInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(writerInput) else {
            throw DropLabError.writerInitializationFailed("Cannot add audio writer input for \(options.targetFormat.rawValue)")
        }
        writer.add(writerInput)

        guard reader.startReading() else {
            throw DropLabError.readerInitializationFailed(reader.error?.localizedDescription ?? "Unknown reader error")
        }
        guard writer.startWriting() else {
            throw DropLabError.writerInitializationFailed(writer.error?.localizedDescription ?? "Unknown writer error")
        }

        let startSampleTime: CMTime
        if let trim = options.effectiveTrimRange {
            startSampleTime = CMTime(seconds: trim.startSeconds, preferredTimescale: 600)
        } else {
            startSampleTime = .zero
        }
        writer.startSession(atSourceTime: startSampleTime)

        struct UncheckedAudioPump: @unchecked Sendable {
            let readerOutput: AVAssetReaderTrackOutput
            let writerInput: AVAssetWriterInput
        }
        let pump = UncheckedAudioPump(readerOutput: readerOutput, writerInput: writerInput)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.furyfish.droplab.audiowriter")
            pump.writerInput.requestMediaDataWhenReady(on: queue) {
                while pump.writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = pump.readerOutput.copyNextSampleBuffer() {
                        if !pump.writerInput.append(sampleBuffer) {
                            pump.writerInput.markAsFinished()
                            continuation.resume()
                            return
                        }
                    } else {
                        pump.writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        if reader.status == .failed {
            writer.cancelWriting()
            throw DropLabError.conversionFailed(reader.error?.localizedDescription ?? "Audio reader failed")
        }

        await writer.finishWriting()
        if writer.status != .completed {
            throw DropLabError.conversionFailed(writer.error?.localizedDescription ?? "Audio writer failed")
        }
    }

    private func avFileType(for format: TargetFormat) throws -> AVFileType {
        switch format {
        case .wav: return .wav
        case .caf: return .caf
        case .aiff: return .aiff
        case .m4a: return .m4a
        default:
            throw DropLabError.unsupportedConversion(from: "audio", to: format)
        }
    }

    private func writerOutputSettings(
        for format: TargetFormat,
        preset: ConversionPreset,
        sampleRate: Double,
        channels: Int
    ) throws -> [String: Any] {
        switch format {
        case .wav, .caf, .aiff:
            let bitDepth: Int = (preset == .pcm24) ? 24 : 16
            let isBigEndian = (format == .aiff)
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: bitDepth,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: isBigEndian,
                AVLinearPCMIsNonInterleaved: false
            ]

        case .m4a:
            if preset == .alac {
                return [
                    AVFormatIDKey: kAudioFormatAppleLossless,
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: channels,
                    AVEncoderBitDepthHintKey: 16
                ]
            } else {
                return [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: channels,
                    AVEncoderBitRateKey: channels == 1 ? 96_000 : 192_000
                ]
            }

        default:
            throw DropLabError.unsupportedConversion(from: "audio", to: format)
        }
    }
}
