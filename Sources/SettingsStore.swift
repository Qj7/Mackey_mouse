import Foundation

extension Notification.Name {
    static let mackeyEnabledChanged = Notification.Name("mackeyEnabledChanged")
}

/// Touched from the UI and from the event-tap callback, both on the main run loop.
final class SettingsStore: @unchecked Sendable {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let reverse = "reverse"
        static let smooth = "smooth"
        static let step = "stepDistance"
        static let speed = "scrollSpeed"
        static let duration = "scrollDuration"
        static let dashCode = "dashKeyCode"
        static let dashMods = "dashKeyModifiers"
        static let toggleCode = "toggleKeyCode"
        static let toggleMods = "toggleKeyModifiers"
        static let blockCode = "blockKeyCode"
        static let blockMods = "blockKeyModifiers"
        static let didPrompt = "didPromptAccess"
    }

    private(set) var enabled: Bool
    private(set) var reverse: Bool
    private(set) var smooth: Bool
    private(set) var step: Double
    private(set) var speed: Double
    private(set) var duration: Double
    private(set) var dashKey: ScrollHotKey
    private(set) var toggleKey: ScrollHotKey
    private(set) var blockKey: ScrollHotKey

    private init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        if defaults.object(forKey: Key.reverse) != nil {
            reverse = defaults.bool(forKey: Key.reverse)
        } else if defaults.object(forKey: "reverseVertical") != nil {
            reverse = defaults.bool(forKey: "reverseVertical")
        } else {
            reverse = true
        }
        smooth = defaults.object(forKey: Key.smooth) as? Bool ?? true
        step = Self.clampedStep(defaults.object(forKey: Key.step) as? Double ?? 33.60)
        speed = Self.clampedSpeed(defaults.object(forKey: Key.speed) as? Double ?? 2.70)
        duration = Self.clampedDuration(defaults.object(forKey: Key.duration) as? Double ?? 4.35)
        dashKey = Self.hotKey(defaults, code: Key.dashCode, mods: Key.dashMods, fallback: .option)
        toggleKey = Self.hotKey(defaults, code: Key.toggleCode, mods: Key.toggleMods, fallback: .shift)
        blockKey = Self.hotKey(defaults, code: Key.blockCode, mods: Key.blockMods, fallback: .command)
    }

    var didPromptForAccess: Bool {
        get { defaults.bool(forKey: Key.didPrompt) }
        set { defaults.set(newValue, forKey: Key.didPrompt) }
    }

    func setEnabled(_ value: Bool) {
        guard value != enabled else { return }
        enabled = value
        defaults.set(value, forKey: Key.enabled)
        NotificationCenter.default.post(name: .mackeyEnabledChanged, object: nil)
    }

    func setReverse(_ value: Bool) {
        reverse = value
        defaults.set(value, forKey: Key.reverse)
    }

    func setSmooth(_ value: Bool) {
        smooth = value
        defaults.set(value, forKey: Key.smooth)
    }

    func setStep(_ value: Double) {
        step = Self.clampedStep(value)
        defaults.set(step, forKey: Key.step)
    }

    func setSpeed(_ value: Double) {
        speed = Self.clampedSpeed(value)
        defaults.set(speed, forKey: Key.speed)
    }

    func setDuration(_ value: Double) {
        duration = Self.clampedDuration(value)
        defaults.set(duration, forKey: Key.duration)
    }

    func setDashKey(_ value: ScrollHotKey) {
        dashKey = value
        store(value, code: Key.dashCode, mods: Key.dashMods)
    }

    func setToggleKey(_ value: ScrollHotKey) {
        toggleKey = value
        store(value, code: Key.toggleCode, mods: Key.toggleMods)
    }

    func setBlockKey(_ value: ScrollHotKey) {
        blockKey = value
        store(value, code: Key.blockCode, mods: Key.blockMods)
    }

    private func store(_ value: ScrollHotKey, code: String, mods: String) {
        defaults.set(Int(value.keyCode), forKey: code)
        defaults.set(Int(value.modifiers), forKey: mods)
    }

    private static func hotKey(_ defaults: UserDefaults, code: String, mods: String, fallback: ScrollHotKey) -> ScrollHotKey {
        guard defaults.object(forKey: code) != nil, defaults.object(forKey: mods) != nil else { return fallback }
        return ScrollHotKey(keyCode: UInt16(defaults.integer(forKey: code)), modifiers: UInt(defaults.integer(forKey: mods)))
    }

    static func clampedStep(_ value: Double) -> Double { min(max(value, 0.1), 100) }
    static func clampedSpeed(_ value: Double) -> Double { min(max(value, 0.1), 6) }
    static func clampedDuration(_ value: Double) -> Double { min(max(value, 0.1), 8) }
}
