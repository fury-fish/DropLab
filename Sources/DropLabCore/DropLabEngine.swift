import Foundation

/// Central conversion orchestrator for DropLab CLI and macOS App.
public final class DropLabEngine: Sendable {
    public static let shared = DropLabEngine()

    public let registry = ConversionRegistry()
    private let audioConverter = AudioConverter()
    private let imageConverter = ImageConverter()
    private let videoConverter = VideoConverter()
    private let dataConverter = DataConverter()

    public init() {}

    /// Converts a single file and returns its `ConversionResult`.
    public func convertFile(
        at sourceURL: URL,
        options: ConversionOptions
    ) async throws -> ConversionResult {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw DropLabError.fileNotFound(sourceURL)
        }

        let startTime = DispatchTime.now()
        let outputURL = SafeOutputNaming.makeOutputURL(for: sourceURL, options: options)
        let converter = try selectConverter(for: sourceURL, targetFormat: options.targetFormat)

        try await converter.convert(sourceURL: sourceURL, to: outputURL, options: options)

        let elapsedNano = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let elapsedMs = max(1, Int(elapsedNano / 1_000_000))

        return ConversionResult(
            sourceURL: sourceURL,
            outputURL: outputURL,
            targetFormat: options.targetFormat,
            preset: options.preset,
            elapsedMilliseconds: elapsedMs
        )
    }

    /// Converts a batch of files and records the batch in `ConversionHistory` for 1-click Undo.
    public func convertBatch(
        urls: [URL],
        options: ConversionOptions,
        recordHistory: Bool = true
    ) async throws -> [ConversionResult] {
        var results: [ConversionResult] = []
        for url in urls {
            let result = try await convertFile(at: url, options: options)
            results.append(result)
        }
        if recordHistory {
            ConversionHistory.shared.record(batch: results)
        }
        return results
    }

    private func selectConverter(for sourceURL: URL, targetFormat: TargetFormat) throws -> any FileConverter {
        let sourceCategory = FileCategory.detect(for: sourceURL)

        switch (sourceCategory, targetFormat.category) {
        case (.audio, .audio), (.video, .audio):
            return audioConverter
        case (.image, .image), (.image, .document), (.document, .image):
            return imageConverter
        case (.video, .video):
            return videoConverter
        case (.data, .data):
            return dataConverter
        default:
            throw DropLabError.unsupportedConversion(
                from: sourceURL.pathExtension.lowercased(),
                to: targetFormat
            )
        }
    }
}
