import Foundation
import AVFoundation
import CoreMedia
import Combine
import DropLabCore

public enum NotchTrayMode: Equatable, Sendable {
    case hidden
    case dropTargetReady
    case expanded
}

@MainActor
public final class NotchTrayViewModel: ObservableObject {
    @Published public var mode: NotchTrayMode = .hidden
    @Published public var isHoveringDropZone: Bool = false

    @Published public var sourceURLs: [URL] = []
    @Published public var slices: [OrbitSliceSpec] = []
    @Published public var selectedSliceIndex: Int = 0
    @Published public var selectedPresetIndex: Int = 0

    // Inline Waveform Trimmer state (for Audio & Video files)
    @Published public var waveform: WaveformSummary? = nil
    @Published public var isTrimEnabled: Bool = false
    @Published public var trimStartSeconds: Double = 0.0
    @Published public var trimEndSeconds: Double = 8.0
    @Published public var isPlayingPreview: Bool = false
    @Published public var playbackPlayheadSeconds: Double = 0.0

    public var onCommitConversion: ((ConversionOptions) -> Void)?
    public var onClose: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var scrollAccumulator: CGFloat = 0

    public init() {}

    public func loadFiles(_ urls: [URL]) {
        stopPreview()
        self.sourceURLs = urls
        self.slices = DropLabEngine.shared.registry.orbitSlices(for: urls)
        self.selectedSliceIndex = 0
        self.selectedPresetIndex = 0
        self.scrollAccumulator = 0

        guard let first = urls.first else { return }
        let category = FileCategory.detect(for: first)

        if category == .audio || category == .video {
            self.waveform = WaveformAnalyzer.fallbackSummary(duration: 10.0)
            self.isTrimEnabled = true
            self.trimStartSeconds = 0.0
            self.trimEndSeconds = 8.0

            Task { @MainActor in
                let summary = await WaveformAnalyzer.analyze(url: first, barCount: 64)
                guard self.sourceURLs.first == first else { return }
                self.waveform = summary
                self.trimStartSeconds = 0.0
                self.trimEndSeconds = min(8.0, summary.durationSeconds)
            }
        } else {
            self.waveform = nil
            self.isTrimEnabled = false
        }
    }

    public var activeSlice: OrbitSliceSpec? {
        guard slices.indices.contains(selectedSliceIndex) else { return nil }
        return slices[selectedSliceIndex]
    }

    public var activePresets: [ConversionPreset] {
        activeSlice?.subOrbitPresets ?? [.standard]
    }

    public var activePreset: ConversionPreset {
        let presets = activePresets
        guard presets.indices.contains(selectedPresetIndex) else {
            return presets.first ?? .standard
        }
        return presets[selectedPresetIndex]
    }

    public func selectSlice(at index: Int) {
        guard slices.indices.contains(index) else { return }
        selectedSliceIndex = index
        selectedPresetIndex = 0
    }

    public func cycleFormat(step: Int) {
        guard !slices.isEmpty else { return }
        let count = slices.count
        let next = (selectedSliceIndex + step % count + count) % count
        selectSlice(at: next)
    }

    public func handleTrackpadScroll(deltaX: CGFloat, deltaY: CGFloat) {
        let dominant = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        scrollAccumulator += dominant
        let threshold: CGFloat = 18.0
        if scrollAccumulator >= threshold {
            scrollAccumulator = 0
            cycleFormat(step: 1)
        } else if scrollAccumulator <= -threshold {
            scrollAccumulator = 0
            cycleFormat(step: -1)
        }
    }

    public var currentConversionOptions: ConversionOptions? {
        guard let slice = activeSlice else { return nil }
        let trimRange: TimeTrimRange?
        if isTrimEnabled && waveform != nil {
            trimRange = TimeTrimRange(startSeconds: trimStartSeconds, endSeconds: trimEndSeconds)
        } else {
            trimRange = nil
        }
        return ConversionOptions(
            targetFormat: slice.targetFormat,
            preset: activePreset,
            customTrimRange: trimRange
        )
    }

    public var previewOutputFilename: String {
        guard let first = sourceURLs.first,
              let opts = currentConversionOptions else {
            return ""
        }
        let out = SafeOutputNaming.makeOutputURL(for: first, options: opts)
        if sourceURLs.count > 1 {
            return "\(out.lastPathComponent) (+\(sourceURLs.count - 1))"
        }
        return out.lastPathComponent
    }

    // MARK: - Live Audio Preview

    public func togglePreview() {
        if isPlayingPreview {
            stopPreview()
        } else {
            startPreview()
        }
    }

    public func startPreview() {
        stopPreview()
        guard let first = sourceURLs.first else { return }
        let item = AVPlayerItem(url: first)
        let avPlayer = AVPlayer(playerItem: item)
        let startCM = CMTime(seconds: trimStartSeconds, preferredTimescale: 600)
        avPlayer.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero)
        playbackPlayheadSeconds = trimStartSeconds

        let endSec = trimEndSeconds
        let interval = CMTime(seconds: 0.04, preferredTimescale: 600)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let sec = CMTimeGetSeconds(time)
                self.playbackPlayheadSeconds = sec
                if sec >= endSec {
                    self.stopPreview()
                }
            }
        }

        self.player = avPlayer
        self.isPlayingPreview = true
        avPlayer.play()
    }

    public func stopPreview() {
        if let player, let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
        player?.pause()
        player = nil
        isPlayingPreview = false
    }

    public static func formatTimestamp(_ seconds: Double) -> String {
        let clamped = max(0, Int(seconds.rounded()))
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
