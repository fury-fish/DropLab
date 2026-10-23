import AppKit
import SwiftUI
import DropLabCore

@MainActor
public final class NotchTrayController: ObservableObject {
    public static let shared = NotchTrayController()

    public let viewModel = NotchTrayViewModel()
    private var panel: NotchTrayPanel?
    private var localKeyMonitor: Any?

    private init() {
        viewModel.onCommitConversion = { [weak self] options in
            Task { @MainActor in
                self?.executeConversion(options: options)
            }
        }
        viewModel.onClose = { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    public var isExpanded: Bool {
        viewModel.mode == .expanded || viewModel.mode == .outputShelf
    }

    public func showDropTargetPill() {
        guard AppSettings.shared.notchTrayEnabled else { return }
        guard !isExpanded else { return }
        ensurePanelPositionedAtTopCenter()
        viewModel.mode = .dropTargetReady
        panel?.orderFrontRegardless()
    }

    public func hideDropTargetPillIfNotExpanded() {
        guard viewModel.mode == .dropTargetReady else { return }
        viewModel.isHoveringDropZone = false
        viewModel.mode = .hidden
        panel?.orderOut(nil)
    }

    public func presentExpanded(with urls: [URL]) {
        let valid = urls.filter { !DropLabEngine.shared.registry.orbitSlices(for: $0).isEmpty }
        guard !valid.isEmpty else { return }

        ensurePanelPositionedAtTopCenter()
        viewModel.loadFiles(valid)
        viewModel.mode = .expanded
        panel?.makeKeyAndOrderFront(nil)
        installKeyboardShortcutsMonitor()
    }

    public func dismiss() {
        removeKeyboardShortcutsMonitor()
        viewModel.stopPreview()
        viewModel.isHoveringDropZone = false
        viewModel.mode = .hidden
        panel?.orderOut(nil)
    }

    private func ensurePanelPositionedAtTopCenter() {
        if panel == nil {
            panel = NotchTrayPanel(viewModel: viewModel) { [weak self] droppedURLs in
                Task { @MainActor in
                    self?.presentExpanded(with: droppedURLs)
                }
            }
        }
        guard let panel else { return }
        let targetScreen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        if let screenFrame = targetScreen?.frame {
            let x = screenFrame.midX - NotchTrayView.panelWidth * 0.5
            let y = screenFrame.maxY - NotchTrayView.panelHeight
            panel.setFrameOrigin(CGPoint(x: x, y: y))
        }
    }

    private func installKeyboardShortcutsMonitor() {
        removeKeyboardShortcutsMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isExpanded else { return event }
            if self.viewModel.mode == .outputShelf {
                if event.keyCode == 53 { // Esc
                    self.dismiss()
                    return nil
                }
                return event
            }
            switch event.keyCode {
            case 53: // Esc
                self.dismiss()
                return nil
            case 36, 76: // Return / Enter
                if let opts = self.viewModel.currentConversionOptions {
                    self.executeConversion(options: opts)
                }
                return nil
            case 49: // Space
                if self.viewModel.waveform != nil {
                    self.viewModel.togglePreview()
                    return nil
                }
                return event
            case 123: // Left
                self.viewModel.cycleFormat(step: -1)
                return nil
            case 124: // Right
                self.viewModel.cycleFormat(step: 1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyboardShortcutsMonitor() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func executeConversion(options: ConversionOptions) {
        let urls = viewModel.sourceURLs
        viewModel.stopPreview()

        Task { @MainActor in
            do {
                let results = try await DropLabEngine.shared.convertBatch(urls: urls, options: options)
                HapticEngine.conversionCompleted()
                if AppSettings.shared.playSoundOnConvert {
                    NSSound(named: NSSound.Name("Glass"))?.play()
                }
                self.viewModel.completedResults = results
                self.viewModel.mode = .outputShelf
            } catch {
                NSSound.beep()
                self.dismiss()
                ConversionToastController.shared.showError(error.localizedDescription)
            }
        }
    }
}
