import AppKit
import SwiftUI
import DropLabCore

@MainActor
public final class ConversionToastController: ObservableObject {
    public static let shared = ConversionToastController()

    @Published public var latestResults: [ConversionResult] = []
    @Published public var errorMessage: String? = nil
    @Published public var isVisible: Bool = false

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    public func showSuccess(results: [ConversionResult], near screenPoint: CGPoint? = nil) {
        guard !results.isEmpty else { return }
        self.errorMessage = nil
        self.latestResults = results
        presentPanel(near: screenPoint, autoHideAfter: 4.5)
    }

    public func showError(_ message: String, near screenPoint: CGPoint? = nil) {
        self.latestResults = []
        self.errorMessage = message
        presentPanel(near: screenPoint, autoHideAfter: 4.0)
    }

    public func dismiss() {
        hideWorkItem?.cancel()
        isVisible = false
        panel?.orderOut(nil)
    }

    private func presentPanel(near screenPoint: CGPoint?, autoHideAfter: TimeInterval) {
        hideWorkItem?.cancel()
        if panel == nil {
            let toastWidth: CGFloat = 420
            let toastHeight: CGFloat = 68
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: toastWidth, height: toastHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .statusBar
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentView = NSHostingView(rootView: ConversionToastView(controller: self))
            self.panel = p
        }

        guard let panel else { return }
        let targetScreen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        if let screenFrame = targetScreen?.visibleFrame {
            let x = screenFrame.midX - panel.frame.width * 0.5
            let y = screenFrame.minY + 48
            panel.setFrameOrigin(CGPoint(x: x, y: y))
        }

        isVisible = true
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideAfter, execute: work)
    }
}

struct ConversionToastView: View {
    @ObservedObject var controller: ConversionToastController

    var body: some View {
        HStack(spacing: 12) {
            if let errorMessage = controller.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                Text(errorMessage)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
            } else if let first = controller.latestResults.first {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        controller.latestResults.count == 1
                            ? first.outputURL.lastPathComponent
                            : "Đã chuyển đổi \(controller.latestResults.count) files (.\(first.targetFormat.rawValue))"
                    )
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                    Text("Hoàn tất trong \(first.elapsedMilliseconds) ms • Ngay cạnh file gốc")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Button {
                    let urls = controller.latestResults.map(\.outputURL)
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                    controller.dismiss()
                } label: {
                    Label("Finder", systemImage: "folder")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)

                Button {
                    ConversionHistory.shared.undoLastBatch()
                    controller.dismiss()
                } label: {
                    Text("Hoàn tác")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 420, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
