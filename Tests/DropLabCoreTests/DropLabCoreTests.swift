import XCTest
import AVFoundation
import CoreGraphics
import ImageIO
import PDFKit
@testable import DropLabCore

final class DropLabCoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DropLabTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testFileCategoryDetectionAndOrbitRegistry() {
        let mp3URL = URL(fileURLWithPath: "/tmp/match.mp3")
        XCTAssertEqual(FileCategory.detect(for: mp3URL), .audio)

        let audioSlices = ConversionRegistry().orbitSlices(for: mp3URL)
        XCTAssertEqual(audioSlices.map(\.targetFormat), [.wav, .caf, .m4a, .mp3, .ogg, .flac])
        XCTAssertTrue(audioSlices[0].subOrbitPresets.contains(.lei16))
        XCTAssertTrue(audioSlices[0].subOrbitPresets.contains(.pcm24))
        XCTAssertTrue(audioSlices[0].subOrbitPresets.contains(.trim8s))

        let heicURL = URL(fileURLWithPath: "/tmp/photo.heic")
        XCTAssertEqual(FileCategory.detect(for: heicURL), .image)
        let imageSlices = ConversionRegistry().orbitSlices(for: heicURL)
        XCTAssertTrue(imageSlices.map(\.targetFormat).contains(.png))
        XCTAssertTrue(imageSlices.map(\.targetFormat).contains(.webp))
        XCTAssertTrue(imageSlices.map(\.targetFormat).contains(.icns))
    }

    func testSafeOutputNamingPreventsOverwrites() throws {
        let source = tempDir.appendingPathComponent("match.mp3")
        try Data("dummy".utf8).write(to: source)

        let options = ConversionOptions(targetFormat: .wav, preset: .lei16)
        let firstURL = SafeOutputNaming.makeOutputURL(for: source, options: options)
        XCTAssertEqual(firstURL.lastPathComponent, "match_LEI16.wav")

        // Create the first output file so a collision occurs next time
        try Data("occupied".utf8).write(to: firstURL)
        let secondURL = SafeOutputNaming.makeOutputURL(for: source, options: options)
        XCTAssertEqual(secondURL.lastPathComponent, "match_LEI16 2.wav")
    }

    func testAudioConversionLEI16AndTrim8s() async throws {
        let sourceURL = tempDir.appendingPathComponent("input_tone.wav")
        try createSineWaveAudio(at: sourceURL, durationSeconds: 10.0)

        // 1. Convert to WAV LEI16 + Mono
        let lei16Result = try await DropLabEngine.shared.convertFile(
            at: sourceURL,
            options: ConversionOptions(targetFormat: .wav, preset: .lei16)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: lei16Result.outputURL.path))
        XCTAssertEqual(lei16Result.outputURL.lastPathComponent, "input_tone_LEI16.wav")

        // 2. Trim first 8 seconds into CAF
        let trimResult = try await DropLabEngine.shared.convertFile(
            at: sourceURL,
            options: ConversionOptions(targetFormat: .caf, preset: .trim8s)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: trimResult.outputURL.path))
        let trimmedAsset = AVURLAsset(url: trimResult.outputURL)
        let trimmedDuration = try await CMTimeGetSeconds(trimmedAsset.load(.duration))
        XCTAssertEqual(trimmedDuration, 8.0, accuracy: 0.25)

        // 3. Convert to M4A (AAC)
        let m4aResult = try await DropLabEngine.shared.convertFile(
            at: sourceURL,
            options: ConversionOptions(targetFormat: .m4a, preset: .standard)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: m4aResult.outputURL.path))
    }

    func testImageConversionScaleAndICNS() async throws {
        let sourceURL = tempDir.appendingPathComponent("avatar.png")
        try createTestPNG(at: sourceURL, width: 128, height: 128)

        // 1. Convert to PNG Scale 2x (256x256)
        let scaledResult = try await DropLabEngine.shared.convertFile(
            at: sourceURL,
            options: ConversionOptions(targetFormat: .png, preset: .scale2x)
        )
        guard let src = CGImageSourceCreateWithURL(scaledResult.outputURL as CFURL, nil),
              let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            XCTFail("Failed to read scaled PNG")
            return
        }
        XCTAssertEqual(cgImg.width, 256)
        XCTAssertEqual(cgImg.height, 256)

        // 2. Convert to JPG (Quality 80%)
        let jpgResult = try await DropLabEngine.shared.convertFile(
            at: sourceURL,
            options: ConversionOptions(targetFormat: .jpg, preset: .quality80)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: jpgResult.outputURL.path))

        // 3. Convert to ICNS
        let icnsResult = try await DropLabEngine.shared.convertFile(
            at: sourceURL,
            options: ConversionOptions(targetFormat: .icns, preset: .standard)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: icnsResult.outputURL.path))
    }

    func testDataConversionJSONAndPlist() async throws {
        let jsonURL = tempDir.appendingPathComponent("config.json")
        let jsonString = #"{"app":"DropLab","version":1}"#
        try Data(jsonString.utf8).write(to: jsonURL)

        let plistResult = try await DropLabEngine.shared.convertFile(
            at: jsonURL,
            options: ConversionOptions(targetFormat: .plist, preset: .xmlPlist)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistResult.outputURL.path))

        let backToJSON = try await DropLabEngine.shared.convertFile(
            at: plistResult.outputURL,
            options: ConversionOptions(targetFormat: .json, preset: .minify)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: backToJSON.outputURL.path))
    }

    func testWaveformAnalyzerAndUndoHistory() async throws {
        let sourceURL = tempDir.appendingPathComponent("waveform_test.wav")
        try createSineWaveAudio(at: sourceURL, durationSeconds: 6.0)

        let summary = await WaveformAnalyzer.analyze(url: sourceURL, barCount: 32)
        XCTAssertEqual(summary.peaks.count, 32)
        XCTAssertEqual(summary.durationSeconds, 6.0, accuracy: 0.25)

        let batch = try await DropLabEngine.shared.convertBatch(
            urls: [sourceURL],
            options: ConversionOptions(targetFormat: .caf, preset: .lei16),
            recordHistory: true
        )
        XCTAssertEqual(batch.count, 1)
        let generatedURL = batch[0].outputURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedURL.path))

        let undone = ConversionHistory.shared.undoLastBatch()
        XCTAssertEqual(undone.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: generatedURL.path))
    }

    func testPDFMergeAndSplit() async throws {
        let img1 = tempDir.appendingPathComponent("page1.png")
        let img2 = tempDir.appendingPathComponent("page2.png")
        try createTestPNG(at: img1, width: 200, height: 200)
        try createTestPNG(at: img2, width: 200, height: 200)

        let mergedBatch = try await DropLabEngine.shared.convertBatch(
            urls: [img1, img2],
            options: ConversionOptions(targetFormat: .pdf, preset: .mergePDF),
            recordHistory: false
        )
        XCTAssertEqual(mergedBatch.count, 1)
        let mergedPDFURL = mergedBatch[0].outputURL
        let pdfDoc = PDFDocument(url: mergedPDFURL)
        XCTAssertEqual(pdfDoc?.pageCount, 2)

        let splitResult = try await DropLabEngine.shared.convertFile(
            at: mergedPDFURL,
            options: ConversionOptions(targetFormat: .pdf, preset: .splitPages)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: splitResult.outputURL.path))
    }

    private func createSineWaveAudio(at url: URL, durationSeconds: Double) throws {
        let sampleRate = 44_100.0
        let frames = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw DropLabError.conversionFailed("Buffer allocation failed")
        }
        buffer.frameLength = frames
        if let ch0 = buffer.floatChannelData?[0], let ch1 = buffer.floatChannelData?[1] {
            for i in 0..<Int(frames) {
                let sample = Float(0.2 * sin(2.0 * .pi * 440.0 * Double(i) / sampleRate))
                ch0[i] = sample
                ch1[i] = sample
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func createTestPNG(at url: URL, width: Int, height: Int) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw DropLabError.conversionFailed("Graphics context failed")
        }
        ctx.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw DropLabError.conversionFailed("PNG destination failed")
        }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
