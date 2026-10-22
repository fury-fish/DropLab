import AppKit
import SwiftUI
import DropLabCore

/// Non-activating top-anchored panel positioned right at the MacBook Notch (or top-center of external displays).
@MainActor
public final class NotchTrayPanel: NSPanel {
    private let receiverView: NotchDropReceiverView

    public init(viewModel: NotchTrayViewModel, onFilesDropped: @escaping ([URL]) -> Void) {
        let frame = NSRect(
            x: 0,
            y: 0,
            width: NotchTrayView.panelWidth,
            height: NotchTrayView.panelHeight
        )
        self.receiverView = NotchDropReceiverView(
            frame: frame,
            viewModel: viewModel,
            onFilesDropped: onFilesDropped
        )

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let hostingView = NSHostingView(rootView: NotchTrayView(viewModel: viewModel))
        hostingView.frame = receiverView.bounds
        hostingView.autoresizingMask = [.width, .height]
        receiverView.addSubview(hostingView)

        self.contentView = receiverView
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchDropReceiverView: NSView {
    private let viewModel: NotchTrayViewModel
    private let onFilesDropped: ([URL]) -> Void

    init(
        frame frameRect: NSRect,
        viewModel: NotchTrayViewModel,
        onFilesDropped: @escaping ([URL]) -> Void
    ) {
        self.viewModel = viewModel
        self.onFilesDropped = onFilesDropped
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        viewModel.isHoveringDropZone = true
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        viewModel.isHoveringDropZone = true
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        viewModel.isHoveringDropZone = false
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        viewModel.isHoveringDropZone = false
        let pb = sender.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else {
            return false
        }
        onFilesDropped(urls)
        return true
    }

    override func scrollWheel(with event: NSEvent) {
        guard viewModel.mode == .expanded else {
            super.scrollWheel(with: event)
            return
        }
        viewModel.handleTrackpadScroll(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
    }

    override func keyDown(with event: NSEvent) {
        guard viewModel.mode == .expanded else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 53: // Esc
            viewModel.onClose?()
        case 36, 76: // Return / Enter
            if let opts = viewModel.currentConversionOptions {
                viewModel.onCommitConversion?(opts)
            }
        case 49: // Space
            if viewModel.waveform != nil {
                viewModel.togglePreview()
            }
        case 123: // Left Arrow
            viewModel.cycleFormat(step: -1)
        case 124: // Right Arrow
            viewModel.cycleFormat(step: 1)
        default:
            super.keyDown(with: event)
        }
    }
}
