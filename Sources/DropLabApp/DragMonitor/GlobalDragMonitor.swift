import AppKit
import Foundation
import DropLabCore

/// Monitors system-wide file drag sessions (`NSPasteboard(name: .drag)`) and triggers
/// the Radial Orbit when the user holds the pointer still for `0.4s` (Concept 1).
@MainActor
public final class GlobalDragMonitor: ObservableObject {
    public static let shared = GlobalDragMonitor()

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var pollTimer: Timer?
    private var lastObservedChangeCount: Int
    private var activeDragURLs: [URL] = []
    private var isDraggingSessionActive: Bool = false
    private var hasPresentedOrbitInCurrentDrag: Bool = false
    private var anchorLocation: CGPoint = .zero
    private var anchorTimestamp: TimeInterval = 0

    private init() {
        self.lastObservedChangeCount = dragPasteboard.changeCount
    }

    public func start() {
        guard pollTimer == nil else { return }
        lastObservedChangeCount = dragPasteboard.changeCount

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollTick() {
        let leftMouseDown = (NSEvent.pressedMouseButtons & 1) != 0
        if !leftMouseDown {
            if isDraggingSessionActive {
                isDraggingSessionActive = false
                hasPresentedOrbitInCurrentDrag = false
                activeDragURLs = []
                NotchTrayController.shared.hideDropTargetPillIfNotExpanded()
            }
            return
        }

        // Check if a new drag session started on the system drag pasteboard
        let currentChangeCount = dragPasteboard.changeCount
        if currentChangeCount != lastObservedChangeCount {
            lastObservedChangeCount = currentChangeCount
            activeDragURLs = extractFileURLsFromDragPasteboard()
            isDraggingSessionActive = !activeDragURLs.isEmpty
            hasPresentedOrbitInCurrentDrag = false
            anchorLocation = NSEvent.mouseLocation
            anchorTimestamp = ProcessInfo.processInfo.systemUptime
            if isDraggingSessionActive && AppSettings.shared.notchTrayEnabled {
                NotchTrayController.shared.showDropTargetPill()
            }
        }

        guard isDraggingSessionActive else { return }

        let currentLoc = NSEvent.mouseLocation
        if isCursorInTopNotchZone(currentLoc) {
            // While hovering near the top Notch drop zone, reset hold timer so Radial Orbit doesn't cover the Notch
            anchorLocation = currentLoc
            anchorTimestamp = ProcessInfo.processInfo.systemUptime
            return
        }

        guard AppSettings.shared.radialOrbitEnabled,
              !hasPresentedOrbitInCurrentDrag,
              !RadialOrbitController.shared.isPresented,
              !NotchTrayController.shared.isExpanded else {
            return
        }

        if AppSettings.shared.requireOptionKeyDuringDrag,
           !NSEvent.modifierFlags.contains(.option) {
            anchorLocation = currentLoc
            anchorTimestamp = ProcessInfo.processInfo.systemUptime
            return
        }

        let dist = hypot(currentLoc.x - anchorLocation.x, currentLoc.y - anchorLocation.y)
        let now = ProcessInfo.processInfo.systemUptime

        // Reset stillness timer if pointer moved more than 6pt
        if dist > 6.0 {
            anchorLocation = currentLoc
            anchorTimestamp = now
            return
        }

        let elapsed = now - anchorTimestamp
        if elapsed >= AppSettings.shared.holdDurationSeconds {
            hasPresentedOrbitInCurrentDrag = true
            RadialOrbitController.shared.present(
                for: activeDragURLs,
                at: currentLoc,
                duringActiveDrag: true
            )
        }
    }

    private func isCursorInTopNotchZone(_ point: CGPoint) -> Bool {
        guard AppSettings.shared.notchTrayEnabled else { return false }
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main else {
            return false
        }
        let topStripHeight: CGFloat = 95
        let horizontalSpan: CGFloat = 420
        let inTopY = point.y >= (screen.frame.maxY - topStripHeight)
        let inCenterX = abs(point.x - screen.frame.midX) <= (horizontalSpan * 0.5)
        return inTopY && inCenterX
    }

    private func extractFileURLsFromDragPasteboard() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = dragPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls.filter { url in
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return exists && !isDir.boolValue
        }
    }
}
