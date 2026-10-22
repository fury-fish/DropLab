import Foundation
import AVFoundation
import CoreMedia

/// Extracts normalized amplitude peak bars and duration from any audio or video file
/// for the Concept 2 Notch Tray Inline Waveform Trimmer.
public struct WaveformSummary: Sendable, Equatable {
    public var durationSeconds: Double
    public var peaks: [Float]

    public init(durationSeconds: Double, peaks: [Float]) {
        self.durationSeconds = durationSeconds
        self.peaks = peaks
    }
}

public enum WaveformAnalyzer {
    public static func analyze(url: URL, barCount: Int = 64) async -> WaveformSummary {
        let asset = AVURLAsset(url: url)
        guard let durationCM = try? await asset.load(.duration) else {
            return fallbackSummary(barCount: barCount)
        }
        let durationSec = max(0.5, CMTimeGetSeconds(durationCM).isFinite ? CMTimeGetSeconds(durationCM) : 10.0)

        guard let tracks = try? await asset.loadTracks(withMediaType: .audio),
              let audioTrack = tracks.first,
              let reader = try? AVAssetReader(asset: asset) else {
            return fallbackSummary(duration: durationSec, barCount: barCount)
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 8_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            return fallbackSummary(duration: durationSec, barCount: barCount)
        }
        reader.add(output)
        guard reader.startReading() else {
            return fallbackSummary(duration: durationSec, barCount: barCount)
        }

        var allSamples: [Int16] = []
        allSamples.reserveCapacity(Int(min(durationSec, 120.0) * 8_000))

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                break
            }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            let sampleCount = length / MemoryLayout<Int16>.size
            guard sampleCount > 0 else { continue }

            var buffer = [Int16](repeating: 0, count: sampleCount)
            buffer.withUnsafeMutableBytes { rawPtr in
                if let base = rawPtr.baseAddress {
                    _ = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
                }
            }
            // Downsample stride to keep memory tiny even on long tracks
            let step = max(1, sampleCount / 512)
            for idx in stride(from: 0, to: sampleCount, by: step) {
                allSamples.append(buffer[idx])
            }
        }

        guard !allSamples.isEmpty else {
            return fallbackSummary(duration: durationSec, barCount: barCount)
        }

        let bucketSize = max(1, allSamples.count / barCount)
        var rawPeaks: [Float] = []
        rawPeaks.reserveCapacity(barCount)

        for b in 0..<barCount {
            let start = b * bucketSize
            if start >= allSamples.count {
                rawPeaks.append(0.15)
                continue
            }
            let end = min(allSamples.count, start + bucketSize)
            var sumSq: Float = 0
            for i in start..<end {
                let norm = Float( abs(Int32(allSamples[i])) ) / Float(Int16.max)
                sumSq += norm * norm
            }
            let rms = sqrt(sumSq / Float(max(1, end - start)))
            rawPeaks.append(rms)
        }

        let maxPeak = max(rawPeaks.max() ?? 1.0, 0.01)
        let normalized = rawPeaks.map { value -> Float in
            let scaled = value / maxPeak
            return min(1.0, max(0.12, pow(scaled, 0.75)))
        }

        return WaveformSummary(durationSeconds: durationSec, peaks: normalized)
    }

    public static func fallbackSummary(duration: Double = 12.0, barCount: Int = 64) -> WaveformSummary {
        let peaks = (0..<barCount).map { i -> Float in
            let x = Double(i) / Double(max(1, barCount - 1))
            let wave = 0.55 + 0.35 * sin(x * .pi * 6.0) * cos(x * .pi * 2.5)
            return Float(min(0.98, max(0.14, abs(wave))))
        }
        return WaveformSummary(durationSeconds: duration, peaks: peaks)
    }
}
