import AppKit
import SwiftUI
import DropLabCore

/// Controls presentation, cursor tracking, and conversion execution for the Radial Orbit overlay.
@MainActor
public final class RadialOrbitController: ObservableObject {
    public static let shared = RadialOrbitController()

    public let viewModel = RadialOrbitViewModel()
    @Published public private(set) var isPresented: Bool = false

    private var panel: RadialOrbitPanel?
    private var trackingTimer: Timer?
    private var keyMonitor: Any?
    private var isDuringActiveDrag: Bool = false
    private var hasCommittedSession: Bool = false

    private init() {
        viewModel.onSelectConversion = { [weak self] format, preset in
            Task { @MainActor in
                self?.triggerConversion(format: format, preset: preset)
            }
        }
        viewModel.onCancel = { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    public func present(
        for urls: [URL],
        at screenCenter: CGPoint,
        duringActiveDrag: Bool
    ) {
        let validURLs = urls.filter { !DropLabEngine.shared.registry.orbitSlices(for: $0).isEmpty }
        guard !validURLs.isEmpty else { return }

        self.isDuringActiveDrag = duringActiveDrag
        self.hasCommittedSession = false
        viewModel.configure(with: validURLs)

        if panel == nil {
            panel = RadialOrbitPanel(viewModel: viewModel)
        }
        guard let panel else { return }

        let size = RadialOrbitGeometry.canvasSize
        let origin = CGPoint(
            x: screenCenter.x - size * 0.5,
            y: screenCenter.y - size * 0.5
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        isPresented = true
        viewModel.isExpanded = true
        HapticEngine.orbitOpened()

        startCursorTracking()
    }

    public func dismiss() {
        stopCursorTracking()
        viewModel.isExpanded = false
        isPresented = false
        panel?.orderOut(nil)
    }

    private func startCursorTracking() {
        stopCursorTracking()

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                Task { @MainActor in
                    self?.dismiss()
                }
            }
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickCursorTracking()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    private func stopCursorTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func tickCursorTracking() {
        guard isPresented, let panel else { return }
        let mouseScreen = NSEvent.mouseLocation
        let frame = panel.frame

        // Convert screen coordinates (bottom-left) to SwiftUI view coordinates (top-left)
        let localX = mouseScreen.x - frame.minX
        let localYFromBottom = mouseScreen.y - frame.minY
        let pointInView = CGPoint(x: localX, y: frame.height - localYFromBottom)

        let movedOutside = viewModel.updateHover(at: pointInView)
        if movedOutside {
            dismiss()
            return
        }

        // If summoned during a live system drag, releasing the left mouse button over an active slice commits the conversion
        if isDuringActiveDrag {
            let leftPressed = (NSEvent.pressedMouseButtons & 1) != 0
            if !leftPressed {
                if let slice = viewModel.activeSlice {
                    triggerConversion(format: slice.targetFormat, preset: viewModel.activePreset)
                } else {
                    dismiss()
                }
            }
        }
    }

    private func triggerConversion(format: TargetFormat, preset: ConversionPreset) {
        guard !hasCommittedSession else { return }
        hasCommittedSession = true
        HapticEngine.conversionCompleted()

        let urls = viewModel.sourceURLs
        let dropPoint = NSEvent.mouseLocation
        dismiss()

        let options = ConversionOptions(targetFormat: format, preset: preset)
        Task { @MainActor in
            do {
                let results = try await DropLabEngine.shared.convertBatch(urls: urls, options: options)
                if AppSettings.shared.playSoundOnConvert {
                    NSSound(named: NSSound.Name("Glass"))?.play()
                }
                if AppSettings.shared.revealInFinderAfterConvert {
                    NSWorkspace.shared.activateFileViewerSelecting(results.map(\.outputURL))
                }
                ConversionToastController.shared.showSuccess(results: results, near: dropPoint)
            } catch {
                NSSound.beep()
                ConversionToastController.shared.showError(error.localizedDescription, near: dropPoint)
            }
        }
    }
}
