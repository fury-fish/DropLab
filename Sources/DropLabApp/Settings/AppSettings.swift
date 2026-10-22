import Foundation
import Combine

/// Persistent user preferences for DropLab on macOS.
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @Published public var radialOrbitEnabled: Bool {
        didSet { UserDefaults.standard.set(radialOrbitEnabled, forKey: "radialOrbitEnabled") }
    }

    @Published public var notchTrayEnabled: Bool {
        didSet { UserDefaults.standard.set(notchTrayEnabled, forKey: "notchTrayEnabled") }
    }

    @Published public var holdDurationSeconds: Double {
        didSet { UserDefaults.standard.set(holdDurationSeconds, forKey: "holdDurationSeconds") }
    }

    @Published public var requireOptionKeyDuringDrag: Bool {
        didSet { UserDefaults.standard.set(requireOptionKeyDuringDrag, forKey: "requireOptionKeyDuringDrag") }
    }

    @Published public var playSoundOnConvert: Bool {
        didSet { UserDefaults.standard.set(playSoundOnConvert, forKey: "playSoundOnConvert") }
    }

    @Published public var revealInFinderAfterConvert: Bool {
        didSet { UserDefaults.standard.set(revealInFinderAfterConvert, forKey: "revealInFinderAfterConvert") }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "radialOrbitEnabled") == nil {
            defaults.set(true, forKey: "radialOrbitEnabled")
        }
        if defaults.object(forKey: "notchTrayEnabled") == nil {
            defaults.set(true, forKey: "notchTrayEnabled")
        }
        if defaults.object(forKey: "holdDurationSeconds") == nil {
            defaults.set(0.4, forKey: "holdDurationSeconds")
        }
        if defaults.object(forKey: "playSoundOnConvert") == nil {
            defaults.set(true, forKey: "playSoundOnConvert")
        }
        self.radialOrbitEnabled = defaults.bool(forKey: "radialOrbitEnabled")
        self.notchTrayEnabled = defaults.bool(forKey: "notchTrayEnabled")
        let storedHold = defaults.double(forKey: "holdDurationSeconds")
        self.holdDurationSeconds = storedHold > 0.1 ? storedHold : 0.4
        self.requireOptionKeyDuringDrag = defaults.bool(forKey: "requireOptionKeyDuringDrag")
        self.playSoundOnConvert = defaults.bool(forKey: "playSoundOnConvert")
        self.revealInFinderAfterConvert = defaults.bool(forKey: "revealInFinderAfterConvert")
    }
}
