import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Status of bundled or system extended codec binaries (`lame`, `cwebp`, `ffmpeg`).
public struct ExtendedCodecStatus: Sendable, Equatable {
    public var lamePath: String?
    public var cwebpPath: String?
    public var ffmpegPath: String?

    public var hasMP3Support: Bool { lamePath != nil || ffmpegPath != nil }
    public var hasWebPSupport: Bool { cwebpPath != nil || ffmpegPath != nil }
    public var hasFFmpegSupport: Bool { ffmpegPath != nil }
}

/// Handles M4 Extended Codecs (`mp3`, `webp`, `ogg`, `flac`, `webm`) and native Video-to-Animated-GIF.
public struct ExtendedCodecConverter: FileConverter {
    private let audioConverter = AudioConverter()
    private let imageConverter = ImageConverter()

    public init() {}

    public static func detectAvailableCodecs() -> ExtendedCodecStatus {
        ExtendedCodecStatus(
            lamePath: locateTool("lame"),
            cwebpPath: locateTool("cwebp"),
            ffmpegPath: locateTool("ffmpeg")
        )
    }

    public static func locateTool(_ name: String) -> String? {
        let fm = FileManager.default
        var candidates: [String] = []
        if let resPath = Bundle.main.resourceURL?.appendingPathComponent("bin/\(name)").path {
            candidates.append(resPath)
        }
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
            "/usr/bin/\(name)"
        ])
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    public func convert(sourceURL: URL, to outputURL: URL, options: ConversionOptions) async throws {
        let sourceCategory = FileCategory.detect(for: sourceURL)

        // 1. Video -> Animated GIF (Pure Native AVAssetImageGenerator + ImageIO GIF Encoder)
        if sourceCategory == .video && options.targetFormat == .gif {
            try await convertVideoToAnimatedGIF(sourceURL: sourceURL, to: outputURL, options: options)
            return
        }

        // 2. Image -> WebP (`cwebp` or `ffmpeg`)
        if options.targetFormat == .webp {
            try await convertImageToWebP(sourceURL: sourceURL, to: outputURL, options: options)
            return
        }

        // 3. Audio/Video -> MP3, OGG, FLAC
        if options.targetFormat == .mp3 || options.targetFormat == .ogg || options.targetFormat == .flac {
            try await convertAudioExtended(sourceURL: sourceURL, to: outputURL, options: options)
            return
        }

        // 4. Video -> WebM
        if options.targetFormat == .webm {
            try await convertVideoToWebM(sourceURL: sourceURL, to: outputURL, options: options)
            return
        }

        throw DropLabError.unsupportedConversion(from: sourceURL.pathExtension, to: options.targetFormat)
    }

    // MARK: - Image -> WebP

    private func convertImageToWebP(
        sourceURL: URL,
        to outputURL: URL,
        options: ConversionOptions
    ) async throws {
        // First preprocess scaling / alpha via native ImageConverter into a temp PNG
        let tempPNG = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("droplab_webp_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempPNG) }

        let pngOptions = ConversionOptions(
            targetFormat: .png,
            preset: options.preset,
            customTrimRange: nil
        )
        try await imageConverter.convert(sourceURL: sourceURL, to: tempPNG, options: pngOptions)

        let quality = (options.preset == .quality80) ? "80" : "90"
        if let cwebp = Self.locateTool("cwebp") {
            try runProcess(
                executablePath: cwebp,
                arguments: ["-quiet", "-q", quality, tempPNG.path, "-o", outputURL.path]
            )
            return
        }
        if let ffmpeg = Self.locateTool("ffmpeg") {
            try runProcess(
                executablePath: ffmpeg,
                arguments: ["-y", "-loglevel", "error", "-i", tempPNG.path, "-quality", quality, outputURL.path]
            )
            return
        }
        throw DropLabError.conversionFailed("Missing cwebp or ffmpeg for WebP encoding")
    }

    // MARK: - Audio -> MP3 / OGG / FLAC

    private func convertAudioExtended(
        sourceURL: URL,
        to outputURL: URL,
        options: ConversionOptions
    ) async throws {
        // Preprocess decode, trim & mono mixdown using native AudioConverter into a temp WAV
        let tempWAV = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("droplab_audio_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: tempWAV) }

        let wavPreset: ConversionPreset = (options.preset == .mono) ? .mono : .lei16
        let wavOptions = ConversionOptions(
            targetFormat: .wav,
            preset: wavPreset,
            customTrimRange: options.effectiveTrimRange
        )
        try await audioConverter.convert(sourceURL: sourceURL, to: tempWAV, options: wavOptions)

        if options.targetFormat == .mp3, let lame = Self.locateTool("lame") {
            var args = ["--quiet", "-V", "2"]
            if options.preset == .mono {
                args.append(contentsOf: ["-m", "m"])
            }
            args.append(contentsOf: [tempWAV.path, outputURL.path])
            try runProcess(executablePath: lame, arguments: args)
            return
        }

        guard let ffmpeg = Self.locateTool("ffmpeg") else {
            throw DropLabError.conversionFailed("Missing ffmpeg/lame for .\(options.targetFormat.rawValue) encoding")
        }

        var args = ["-y", "-loglevel", "error", "-i", tempWAV.path]
        switch options.targetFormat {
        case .mp3:
            args.append(contentsOf: ["-codec:a", "libmp3lame", "-qscale:a", "2"])
        case .ogg:
            args.append(contentsOf: ["-codec:a", "libvorbis", "-qscale:a", "5"])
        case .flac:
            args.append(contentsOf: ["-codec:a", "flac"])
        default:
            break
        }
        args.append(outputURL.path)
        try runProcess(executablePath: ffmpeg, arguments: args)
    }

    // MARK: - Video -> WebM

    private func convertVideoToWebM(
        sourceURL: URL,
        to outputURL: URL,
        options: ConversionOptions
    ) async throws {
        guard let ffmpeg = Self.locateTool("ffmpeg") else {
            throw DropLabError.conversionFailed("Missing ffmpeg for WebM encoding")
        }
        var args = ["-y", "-loglevel", "error"]
        if let trim = options.effectiveTrimRange {
            args.append(contentsOf: [
                "-ss", String(format: "%.2f", trim.startSeconds),
                "-to", String(format: "%.2f", trim.endSeconds)
            ])
        }
        args.append(contentsOf: ["-i", sourceURL.path])
        if options.preset == .muteAudio {
            args.append("-an")
        }
        args.append(contentsOf: [
            "-c:v", "libvpx-vp9",
            "-crf", "32",
            "-b:v", "0",
            "-deadline", "realtime",
            "-cpu-used", "4",
            outputURL.path
        ])
        try runProcess(executablePath: ffmpeg, arguments: args)
    }

    // MARK: - Video -> Animated GIF (100% Native ImageIO + AVAssetImageGenerator)

    private func convertVideoToAnimatedGIF(
        sourceURL: URL,
        to outputURL: URL,
        options: ConversionOptions
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let durationCM = try await asset.load(.duration)
        let totalSec = max(0.2, CMTimeGetSeconds(durationCM))

        let startSec = options.effectiveTrimRange?.startSeconds ?? 0.0
        let endSec = min(totalSec, options.effectiveTrimRange?.endSeconds ?? min(totalSec, 8.0))
        let clipDuration = max(0.2, endSec - startSec)

        let fps: Double = (options.preset == .fps15) ? 15.0 : 10.0
        let frameCount = max(2, min(120, Int((clipDuration * fps).rounded())))
        let frameDelay = 1.0 / fps

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw DropLabError.writerInitializationFailed("Cannot create animated GIF destination")
        }

        let gifFileProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifFileProps as CFDictionary)

        let frameProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay
            ]
        ]

        for i in 0..<frameCount {
            let t = startSec + (Double(i) / Double(max(1, frameCount - 1))) * clipDuration
            let cmTime = CMTime(seconds: t, preferredTimescale: 600)
            if let (cgImage, _) = try? await generator.image(at: cmTime) {
                CGImageDestinationAddImage(destination, cgImage, frameProps as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw DropLabError.conversionFailed("Failed to finalize animated GIF")
        }
    }

    private func runProcess(executablePath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Process exited with code \(process.terminationStatus)"
            throw DropLabError.conversionFailed(errMsg)
        }
    }
}
