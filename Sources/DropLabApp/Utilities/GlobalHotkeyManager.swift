import AppKit
import Carbon

/// Registers a system-wide global hotkey (`⌥Space` / `Option + Space`) via Carbon `RegisterEventHotKey`
/// (does not require Accessibility permissions) to summon the Radial Orbit for selected Finder files.
@MainActor
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    public var onHotkeyPressed: (() -> Void)?

    private init() {}

    public func registerOptionSpaceHotkey() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, _, _ in
            Task { @MainActor in
                GlobalHotkeyManager.shared.onHotkeyPressed?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x444C4142), id: 1) // 'DLAB'
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(optionKey)

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}
