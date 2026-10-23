import AppKit
import SwiftUI
import DropLabCore

/// Non-activating floating NSPanel that renders the Radial Orbit directly under the mouse cursor
/// and intercepts macOS file drag-and-drop operations cleanly.
@MainActor
public final class RadialOrbitPanel: NSPanel {
    private let dropHostView: OrbitDropReceiverView

    public init(viewModel: RadialOrbitViewModel) {
        let size = RadialOrbitGeometry.canvasSize
        let frame = NSRect(x: 0, y: 0, width: size, height: size)
        self.dropHostView = OrbitDropReceiverView(frame: frame, viewModel: viewModel)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let hostingView = NSHostingView(rootView: RadialOrbitView(viewModel: viewModel))
        hostingView.frame = dropHostView.bounds
        hostingView.autoresizingMask = [.width, .height]
        dropHostView.addSubview(hostingView)

        self.contentView = dropHostView
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}

/// Transparent wrapper NSView that registers for `.fileURL` drag operations so releasing a dragged Finder file
/// over an active Radial Orbit slice performs the conversion without moving the source file in Finder.
@MainActor
final class OrbitDropReceiverView: NSView {
    private let viewModel: RadialOrbitViewModel

    init(frame frameRect: NSRect, viewModel: RadialOrbitViewModel) {
        self.viewModel = viewModel
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        updateHoverFromDraggingInfo(sender)
        return viewModel.activeSlice != nil ? .copy : []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let shouldDismiss = updateHoverFromDraggingInfo(sender)
        if shouldDismiss {
            viewModel.onCancel?()
            return []
        }
        return viewModel.activeSlice != nil ? .copy : []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        viewModel.hoveredSliceIndex = nil
        viewModel.hoveredSubPresetIndex = nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        _ = updateHoverFromDraggingInfo(sender)
        guard let slice = viewModel.activeSlice else {
            return false
        }
        let pb = sender.draggingPasteboard
        let readOpts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let droppedURLs = pb.readObjects(forClasses: [NSURL.self], options: readOpts) as? [URL],
           !droppedURLs.isEmpty {
            viewModel.sourceURLs = droppedURLs.map { ($0 as NSURL).filePathURL ?? $0 }
        }
        let preset = viewModel.activePreset
        viewModel.onSelectConversion?(slice.targetFormat, preset)
        return true
    }

    @discardableResult
    private func updateHoverFromDraggingInfo(_ sender: any NSDraggingInfo) -> Bool {
        let locInWindow = sender.draggingLocation
        let locInView = convert(locInWindow, from: nil)
        // Convert AppKit bottom-left origin to SwiftUI top-left origin
        let flippedPoint = CGPoint(x: locInView.x, y: bounds.height - locInView.y)
        return viewModel.updateHover(at: flippedPoint)
    }
}
