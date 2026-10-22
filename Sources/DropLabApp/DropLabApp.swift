import AppKit
import SwiftUI
import AVFoundation
import DropLabCore

@main
@MainActor
final class DropLabAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = DropLabAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        GlobalDragMonitor.shared.start()

        // If launched with `--demo-orbit`, immediately pop up the Radial Orbit with a demo audio file
        if CommandLine.arguments.contains("--demo-orbit") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.triggerDemoAudioOrbit()
            }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "circle.hexagongrid.fill",
                accessibilityDescription: "DropLab"
            )
            button.imagePosition = .imageLeading
            button.title = "DropLab"
        }

        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "🧪 DropLab — Vòng Xoay Trọng Lực", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let hintItem = NSMenuItem(
            title: "Kéo file bất kỳ trong Finder & giữ yên 0.4s",
            action: nil,
            keyEquivalent: ""
        )
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        menu.addItem(.separator())

        let demoAudioItem = NSMenuItem(
            title: "🌀 Mở Vòng Xoay Mẫu (Audio: match.wav)",
            action: #selector(triggerDemoAudioOrbit),
            keyEquivalent: "d"
        )
        demoAudioItem.target = self
        menu.addItem(demoAudioItem)

        let demoImageItem = NSMenuItem(
            title: "🖼️ Mở Vòng Xoay Mẫu (Image: sample.png)",
            action: #selector(triggerDemoImageOrbit),
            keyEquivalent: "i"
        )
        demoImageItem.target = self
        menu.addItem(demoImageItem)

        let pickFileItem = NSMenuItem(
            title: "📂 Chọn File để Mở Vòng Xoay...",
            action: #selector(pickFileAndOpenOrbit),
            keyEquivalent: "o"
        )
        pickFileItem.target = self
        menu.addItem(pickFileItem)

        menu.addItem(.separator())

        let undoItem = NSMenuItem(
            title: "↩ Hoàn tác lần chuyển đổi gần nhất",
            action: #selector(undoLastConversion),
            keyEquivalent: "z"
        )
        undoItem.target = self
        menu.addItem(undoItem)

        let settingsItem = NSMenuItem(
            title: "⚙️ Cài đặt Vòng Xoay...",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Thoát DropLab",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func triggerDemoAudioOrbit() {
        guard let demoURL = try? DemoSampleGenerator.makeSampleAudioFile() else { return }
        let center = screenCenterPoint()
        RadialOrbitController.shared.present(
            for: [demoURL],
            at: center,
            duringActiveDrag: false
        )
    }

    @objc private func triggerDemoImageOrbit() {
        guard let demoURL = try? DemoSampleGenerator.makeSampleImageFile() else { return }
        let center = screenCenterPoint()
        RadialOrbitController.shared.present(
            for: [demoURL],
            at: center,
            duringActiveDrag: false
        )
    }

    @objc private func pickFileAndOpenOrbit() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Mở Vòng Xoay"
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            let center = screenCenterPoint()
            RadialOrbitController.shared.present(
                for: panel.urls,
                at: center,
                duringActiveDrag: false
            )
        }
    }

    @objc private func undoLastConversion() {
        let removed = ConversionHistory.shared.undoLastBatch()
        if removed.isEmpty {
            NSSound.beep()
        } else {
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
    }

    @objc private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "Cài đặt DropLab"
            win.center()
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func screenCenterPoint() -> CGPoint {
        if let screen = NSScreen.main {
            return CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        }
        return NSEvent.mouseLocation
    }
}

/// Generates synthetic sample files in `/tmp/DropLabDemo` so the user can test Radial Orbit immediately.
enum DemoSampleGenerator {
    static var demoDirectory: URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DropLabDemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func makeSampleAudioFile() throws -> URL {
        let url = demoDirectory.appendingPathComponent("match.wav")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let sampleRate = 44_100.0
        let durationSeconds = 10.0
        let totalFrames = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw DropLabError.conversionFailed("Cannot create demo audio buffer")
        }
        buffer.frameLength = totalFrames
        if let ch0 = buffer.floatChannelData?[0], let ch1 = buffer.floatChannelData?[1] {
            for i in 0..<Int(totalFrames) {
                let t = Double(i) / sampleRate
                let sample = Float(0.25 * sin(2.0 * .pi * 440.0 * t) + 0.15 * sin(2.0 * .pi * 660.0 * t))
                ch0[i] = sample
                ch1[i] = sample
            }
        }
        let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        try audioFile.write(from: buffer)
        return url
    }

    static func makeSampleImageFile() throws -> URL {
        let url = demoDirectory.appendingPathComponent("sample.png")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let width = 512
        let height = 512
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
            throw DropLabError.conversionFailed("Cannot create demo image context")
        }
        ctx.setFillColor(CGColor(red: 0.12, green: 0.52, blue: 0.96, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 1.0, green: 0.58, blue: 0.10, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: 96, y: 96, width: 320, height: 320))

        guard let img = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw DropLabError.conversionFailed("Cannot encode demo PNG")
        }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        return url
    }
}
