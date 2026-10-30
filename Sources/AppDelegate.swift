import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = ScrollEngine()
    private let settingsWindow = SettingsWindowController()
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem?
    private var accessItem: NSMenuItem?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enabledChanged),
            name: .mackeyEnabledChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessChanged),
            name: .mackeyAccessChanged,
            object: nil
        )
        buildStatusItem()
        engine.startIfNeeded()
        beginPermissionWatch()
        settingsWindow.show()
        if !engine.isTapRunning {
            presentAccessAlert()
        }
    }

    private func presentAccessAlert() {
        AccessibilityPermission.prompt()
        let alert = NSAlert()
        alert.messageText = "Mackey cannot intercept the mouse wheel"
        alert.informativeText = """
        macOS reports this binary is not trusted for Accessibility (AXIsProcessTrusted=false), so CGEvent taps cannot be created and Invert cannot work.

        The toggle in System Settings can stay ON for an old build after rebuild. For /Applications/Mackey.app:
        1. Turn Mackey OFF, then ON again
        2. Or remove it (−) and add /Applications/Mackey.app again (+)
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Retry")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityPermission.openSettings()
        }
        engine.startIfNeeded()
        settingsWindow.refreshPermissionNote()
        updateAccessItem()
        if !engine.isTapRunning {
            beginPermissionWatch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = menuBarImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Mackey"
        }

        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Mackey", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let enabled = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabledItem = enabled
        menu.addItem(enabled)

        let settings = NSMenuItem(title: "Preferences…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let access = NSMenuItem(title: "Доступ", action: #selector(requestAccess), keyEquivalent: "")
        access.target = self
        accessItem = access
        menu.addItem(access)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Mackey", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        enabledItem?.state = SettingsStore.shared.enabled ? .on : .off
        updateAccessItem()
        engine.startIfNeeded()
    }

    @objc private func enabledChanged() {
        if SettingsStore.shared.enabled {
            engine.startIfNeeded()
        } else {
            engine.stop()
        }
        enabledItem?.state = SettingsStore.shared.enabled ? .on : .off
    }

    @objc private func toggleEnabled() {
        SettingsStore.shared.setEnabled(!SettingsStore.shared.enabled)
        enabledItem?.state = SettingsStore.shared.enabled ? .on : .off
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func requestAccess() {
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.prompt()
        }
        AccessibilityPermission.openSettings()
    }

    @objc private func quit() {
        engine.stop()
        NSApp.terminate(nil)
    }

    @objc private func accessChanged() {
        settingsWindow.refreshPermissionNote()
        updateAccessItem()
    }

    @objc private func permissionTick() {
        engine.startIfNeeded()
        settingsWindow.refreshPermissionNote()
        updateAccessItem()
        if AccessibilityPermission.isTrusted {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func beginPermissionWatch() {
        let timer = Timer(timeInterval: 2.0, target: self, selector: #selector(permissionTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func updateAccessItem() {
        if AccessibilityPermission.isTrusted {
            accessItem?.title = "Accessibility allowed"
            accessItem?.isEnabled = false
        } else {
            accessItem?.title = "Allow Accessibility…"
            accessItem?.isEnabled = true
        }
    }

    private func menuBarImage() -> NSImage {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            let side = NSStatusBar.system.thickness
            image.size = NSSize(width: side, height: side)
            return image
        }
        return NSImage()
    }

}
