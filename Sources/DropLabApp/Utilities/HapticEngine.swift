import AppKit

/// Triggers tactile Force Touch trackpad haptics when crossing Radial Orbit slices or scrolling the Notch Tray.
@MainActor
public enum HapticEngine {
    public static func sliceChanged() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    public static func orbitOpened() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    public static func conversionCompleted() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}
