import AppKit
import ApplicationServices
import Darwin

extension Notification.Name {
    static let mackeyAccessChanged = Notification.Name("mackeyAccessChanged")
}

enum AccessibilityPermission {
    /// Set by ScrollEngine when a tap is actually installed. AXIsProcessTrusted() can
    /// lag or disagree with System Settings after adhoc rebuilds.
    nonisolated(unsafe) static var tapActive = false

    static var isTrusted: Bool {
        // Prefer the real OS flag. tapActive only means we already created a tap.
        AXIsProcessTrusted() || tapActive
    }

    static var isProcessTrustedByOS: Bool {
        AXIsProcessTrusted()
    }

    static func prompt() {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "kAXTrustedCheckOptionPrompt") else {
            return
        }
        let key = symbol.load(as: Unmanaged<CFString>.self).takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for value in candidates {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
