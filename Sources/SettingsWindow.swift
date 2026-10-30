import AppKit

private final class PreferenceTabView: NSControl {
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    var isChosen = false {
        didSet { applyChrome() }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 70, height: 46) }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = 9
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isChosen {
            layer?.backgroundColor = (dark ? NSColor(white: 1, alpha: 0.16) : NSColor(white: 0, alpha: 0.07)).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = (dark ? NSColor(white: 1, alpha: 0.10) : NSColor(white: 0, alpha: 0.06)).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
        }
        let tint: NSColor = isChosen ? .labelColor : .secondaryLabelColor
        icon.contentTintColor = tint
        titleLabel.textColor = tint
    }

    init(symbolName: String, title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 70, height: 46))
        wantsLayer = true
        layer?.masksToBounds = true

        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 70),
            heightAnchor.constraint(equalToConstant: 46),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 1),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        var last = event
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            last = next
            if next.type == .leftMouseUp { break }
        }
        let point = convert(last.locationInWindow, from: nil)
        if bounds.contains(point) {
            sendAction(action, to: target)
        }
    }

    private func applyChrome() {
        needsDisplay = true
    }
}

/// Rounded key cap whose label stays on the leading edge, including after the user picks a new key.
private final class KeyCapButton: NSControl {
    private let titleLabel = NSTextField(labelWithString: "")
    private var recording = false

    override var intrinsicContentSize: NSSize {
        let font = NSFont.systemFont(ofSize: 13)
        let textWidth = (titleLabel.stringValue as NSString).size(withAttributes: [.font: font]).width
        return NSSize(width: ceil(textWidth) + 22, height: 26)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = 6
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if recording {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(dark ? 0.28 : 0.16).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
        } else {
            layer?.backgroundColor = (dark ? NSColor(white: 1, alpha: 0.12) : NSColor(white: 0, alpha: 0.06)).cgColor
            layer?.borderWidth = 0
        }
        titleLabel.textColor = .labelColor
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.alignment = .left
        titleLabel.lineBreakMode = .byClipping
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { nil }

    func setKeyTitle(_ title: String, recording: Bool) {
        titleLabel.stringValue = title
        self.recording = recording
        invalidateIntrinsicContentSize()
        needsLayout = true
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        var last = event
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            last = next
            if next.type == .leftMouseUp { break }
        }
        let point = convert(last.locationInWindow, from: nil)
        if bounds.contains(point) {
            sendAction(action, to: target)
        }
    }
}

private final class RecordingWindow: NSWindow {
    weak var recorder: SettingsWindowController?

    override func sendEvent(_ event: NSEvent) {
        guard recorder?.isRecording == true else {
            super.sendEvent(event)
            return
        }
        switch event.type {
        case .keyDown:
            recorder?.consumeKeyDown(event)
        case .flagsChanged:
            recorder?.consumeFlags(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            recorder?.cancelRecording()
            super.sendEvent(event)
        default:
            super.sendEvent(event)
        }
    }
}

final class SettingsWindowController: NSWindowController, NSToolbarDelegate, NSWindowDelegate {
    private let generalIdentifier = NSToolbarItem.Identifier("general")
    private let aboutIdentifier = NSToolbarItem.Identifier("about")
    private let generalTab = PreferenceTabView(symbolName: "gearshape.fill", title: "General")
    private let aboutTab = PreferenceTabView(symbolName: "info.circle.fill", title: "About")
    private let pageHost = NSView()
    private var generalPage: NSView!
    private var aboutPage: NSView!

    private let smoothCheck = NSButton(checkboxWithTitle: "Enable seamless scrolling", target: nil, action: nil)
    private let reverseCheck = NSButton(checkboxWithTitle: "Invert wheel direction", target: nil, action: nil)
    private let dashButton = KeyCapButton()
    private let toggleButton = KeyCapButton()
    private let blockButton = KeyCapButton()

    private let stepSlider = NSSlider()
    private let stepField = NSTextField()
    private let stepStepper = NSStepper()
    private let speedSlider = NSSlider()
    private let speedField = NSTextField()
    private let speedStepper = NSStepper()
    private let durationSlider = NSSlider()
    private let durationField = NSTextField()
    private let durationStepper = NSStepper()
    private let accessNote = NSTextField(wrappingLabelWithString: "Mackey cannot invert the wheel until this exact app is allowed in System Settings → Privacy & Security → Accessibility. Turn Mackey off/on there (use /Applications/Mackey.app).")
    private let accessButton = NSButton(title: "Open Accessibility Settings", target: nil, action: nil)
    private let accessRow = NSStackView()

    private let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private enum RecordingTarget {
        case dash, toggle, block
    }

    private var recording: RecordingTarget?
    private var applyingControls = false

    var isRecording: Bool { recording != nil }

    convenience init() {
        let window = RecordingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 490),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .preference
        window.minSize = NSSize(width: 580, height: 460)
        self.init(window: window)
        window.recorder = self
        window.delegate = self

        let toolbar = NSToolbar(identifier: "MackeyPreferences")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        generalTab.target = self
        generalTab.action = #selector(showGeneral)
        aboutTab.target = self
        aboutTab.action = #selector(showAbout)

        generalPage = buildGeneral()
        aboutPage = buildAbout()
        window.contentView = pageHost
        pin(generalPage)
        pin(aboutPage)
        select(generalIdentifier)
        wireControls()
        reload()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessChanged),
            name: .mackeyAccessChanged,
            object: nil
        )
    }

    func show() {
        reload()
        NSApp.setActivationPolicy(.regular)
        guard let window else { return }
        window.collectionBehavior.formUnion([.moveToActiveSpace])
        window.level = .floating
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let screen {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            ))
        }
        refreshPermissionNote()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    @objc private func accessChanged() {
        refreshPermissionNote()
    }

    func refreshPermissionNote() {
        accessRow.isHidden = AccessibilityPermission.isTrusted
    }

    @objc private func openAccessibility() {
        AccessibilityPermission.prompt()
        AccessibilityPermission.openSettings()
    }

    func windowWillClose(_ notification: Notification) {
        window?.level = .normal
        NSApp.setActivationPolicy(.accessory)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case generalIdentifier:
            item.label = "General"
            item.paletteLabel = "General"
            item.toolTip = "General"
            item.view = generalTab
            item.action = #selector(showGeneral)
        case aboutIdentifier:
            item.label = "About"
            item.paletteLabel = "About"
            item.toolTip = "About"
            item.view = aboutTab
            item.action = #selector(showAbout)
        default:
            return nil
        }
        item.target = self
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [generalIdentifier, aboutIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [generalIdentifier, aboutIdentifier]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [generalIdentifier, aboutIdentifier]
    }

    @objc private func showGeneral() {
        select(generalIdentifier)
    }

    @objc private func showAbout() {
        select(aboutIdentifier)
    }

    private func select(_ identifier: NSToolbarItem.Identifier) {
        window?.toolbar?.selectedItemIdentifier = identifier
        generalTab.isChosen = identifier == generalIdentifier
        aboutTab.isChosen = identifier == aboutIdentifier
        generalPage?.isHidden = identifier != generalIdentifier
        aboutPage?.isHidden = identifier != aboutIdentifier
    }

    private func pin(_ page: NSView) {
        page.translatesAutoresizingMaskIntoConstraints = false
        pageHost.addSubview(page)
        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: pageHost.topAnchor),
            page.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: pageHost.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor)
        ])
    }

    func consumeKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            cancelRecording()
            return
        }
        let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
        assign(ScrollHotKey(keyCode: event.keyCode, modifiers: mods.rawValue))
    }

    func consumeFlags(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !mods.isEmpty else { return }
        assign(ScrollHotKey(keyCode: ScrollHotKey.modifierOnly, modifiers: mods.rawValue))
    }

    func cancelRecording() {
        recording = nil
        refreshKeyButtons()
    }

    private func assign(_ hotkey: ScrollHotKey) {
        guard hotkey.modifierFlags != [] || hotkey.keyCode != ScrollHotKey.modifierOnly else { return }
        let settings = SettingsStore.shared
        switch recording {
        case .dash: settings.setDashKey(hotkey)
        case .toggle: settings.setToggleKey(hotkey)
        case .block: settings.setBlockKey(hotkey)
        case nil: break
        }
        recording = nil
        refreshKeyButtons()
    }

    private func buildGeneral() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        prepareCheck(smoothCheck, action: #selector(toggleSmooth))
        prepareCheck(reverseCheck, action: #selector(toggleReverse))
        prepareKey(dashButton, action: #selector(recordDash))
        prepareKey(toggleButton, action: #selector(recordToggle))
        prepareKey(blockButton, action: #selector(recordBlock))

        accessNote.font = .systemFont(ofSize: 12)
        accessNote.textColor = .secondaryLabelColor
        accessNote.alignment = .left
        accessNote.preferredMaxLayoutWidth = 520
        accessButton.target = self
        accessButton.action = #selector(openAccessibility)
        accessButton.bezelStyle = .rounded
        accessButton.font = .systemFont(ofSize: 12)
        accessButton.setContentHuggingPriority(.required, for: .horizontal)
        accessRow.orientation = .vertical
        accessRow.alignment = .leading
        accessRow.spacing = 8
        accessRow.addArrangedSubview(accessNote)
        accessRow.addArrangedSubview(accessButton)

        let smoothRow = labeledRow("Smooth Scrolling", smoothCheck, align: .centerY)
        let reverseRow = labeledRow("Scroll Reverse", reverseCheck, align: .centerY)
        let dashRow = keyRow("Dash Key", dashButton, "Increase scrolling speed on long pages")
        let toggleRow = keyRow("Toggle Key", toggleButton, "Change vertical scrolling to horizontal scrolling")
        let blockRow = keyRow("Block Key", blockButton, "Temporarily block smooth scrolling")
        let separator = NSBox()
        separator.boxType = .separator
        let stepRow = makeSliderRow(stepSlider, stepField, stepStepper, title: "Step", caption: "Sets the minimum scroll distance", min: 0.1, max: 100, increment: 0.1, action: #selector(stepChanged(_:)))
        let speedRow = makeSliderRow(speedSlider, speedField, speedStepper, title: "Speed", caption: "Sets scrolling acceleration", min: 0.1, max: 6, increment: 0.01, action: #selector(speedChanged(_:)))
        let durationRow = makeSliderRow(durationSlider, durationField, durationStepper, title: "Duration", caption: "Sets the duration of the scroll animation", min: 0.1, max: 8, increment: 0.01, action: #selector(durationChanged(_:)))

        for row in [accessRow, smoothRow, reverseRow, dashRow, toggleRow, blockRow, separator, stepRow, speedRow, durationRow] {
            stack.addArrangedSubview(row)
        }
        stack.setCustomSpacing(18, after: accessRow)
        stack.setCustomSpacing(26, after: reverseRow)
        stack.setCustomSpacing(22, after: blockRow)
        stack.setCustomSpacing(20, after: separator)

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -36),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -28)
        ])
        for view in stack.arrangedSubviews {
            view.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            view.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        }
        return content
    }

    private func buildAbout() -> NSView {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: "Mackey")
        name.font = .systemFont(ofSize: 22, weight: .semibold)
        name.alignment = .left

        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = .systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .left

        let copyright = aboutText(
            "Copyright © 2026\nThe copyright holders of this product are its author and Auto.",
            size: 13,
            color: .labelColor
        )
        let heading = NSTextField(labelWithString: "Free License")
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        heading.alignment = .left
        let body = aboutText(
            """
            Mackey is free of charge. You may use this application without payment.

            Copyright in this specific product belongs to its author and Auto. This license covers Mackey only.

            You may copy and share Mackey if this notice remains with the copy and the copyright holders stay named as they are here.

            The software is provided as is, without warranty of any kind.
            """,
            size: 13,
            color: .labelColor
        )

        for view in [name, versionLabel, copyright, heading, body] {
            stack.addArrangedSubview(view)
        }
        stack.setCustomSpacing(4, after: name)
        stack.setCustomSpacing(18, after: versionLabel)
        stack.setCustomSpacing(18, after: copyright)
        stack.setCustomSpacing(8, after: heading)

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -36)
        ])
        for view in stack.arrangedSubviews {
            view.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            view.trailingAnchor.constraint(lessThanOrEqualTo: stack.trailingAnchor).isActive = true
        }
        body.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        copyright.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        return content
    }

    private func aboutText(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        label.alignment = .left
        label.preferredMaxLayoutWidth = 560
        return label
    }

    private func wireControls() {
        for field in [stepField, speedField, durationField] {
            field.target = self
            field.action = #selector(fieldCommitted(_:))
        }
    }

    private func reload() {
        applyingControls = true
        defer { applyingControls = false }
        let settings = SettingsStore.shared
        smoothCheck.state = settings.smooth ? .on : .off
        reverseCheck.state = settings.reverse ? .on : .off
        apply(settings.step, slider: stepSlider, field: stepField, stepper: stepStepper)
        apply(settings.speed, slider: speedSlider, field: speedField, stepper: speedStepper)
        apply(settings.duration, slider: durationSlider, field: durationField, stepper: durationStepper)
        refreshKeyButtons()
    }

    private func refreshKeyButtons() {
        setKeyTitle(dashButton, settings: SettingsStore.shared.dashKey, recording: recording == .dash)
        setKeyTitle(toggleButton, settings: SettingsStore.shared.toggleKey, recording: recording == .toggle)
        setKeyTitle(blockButton, settings: SettingsStore.shared.blockKey, recording: recording == .block)
    }

    private func setKeyTitle(_ button: KeyCapButton, settings: ScrollHotKey, recording: Bool) {
        button.setKeyTitle(recording ? "Type a key" : settings.title, recording: recording)
    }

    private func apply(_ value: Double, slider: NSSlider, field: NSTextField, stepper: NSStepper) {
        slider.doubleValue = value
        stepper.doubleValue = value
        field.stringValue = decimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    @objc private func toggleSmooth(_ sender: NSButton) {
        SettingsStore.shared.setSmooth(sender.state == .on)
    }

    @objc private func toggleReverse(_ sender: NSButton) {
        SettingsStore.shared.setReverse(sender.state == .on)
    }

    @objc private func recordDash() { beginRecording(.dash) }
    @objc private func recordToggle() { beginRecording(.toggle) }
    @objc private func recordBlock() { beginRecording(.block) }

    private func beginRecording(_ target: RecordingTarget) {
        window?.makeFirstResponder(nil)
        recording = target
        refreshKeyButtons()
    }

    @objc private func stepChanged(_ sender: NSControl) {
        commit(sender, slider: stepSlider, field: stepField, stepper: stepStepper, save: SettingsStore.shared.setStep)
    }

    @objc private func speedChanged(_ sender: NSControl) {
        commit(sender, slider: speedSlider, field: speedField, stepper: speedStepper, save: SettingsStore.shared.setSpeed)
    }

    @objc private func durationChanged(_ sender: NSControl) {
        commit(sender, slider: durationSlider, field: durationField, stepper: durationStepper, save: SettingsStore.shared.setDuration)
    }

    @objc private func fieldCommitted(_ sender: NSTextField) {
        if sender === stepField { stepChanged(sender) }
        else if sender === speedField { speedChanged(sender) }
        else if sender === durationField { durationChanged(sender) }
    }

    private func commit(
        _ sender: NSControl,
        slider: NSSlider,
        field: NSTextField,
        stepper: NSStepper,
        save: (Double) -> Void
    ) {
        guard !applyingControls else { return }
        let raw = sender === field ? (decimalFormatter.number(from: field.stringValue)?.doubleValue ?? sender.doubleValue) : sender.doubleValue
        save(raw)
        applyingControls = true
        let stored: Double
        if slider === stepSlider { stored = SettingsStore.shared.step }
        else if slider === speedSlider { stored = SettingsStore.shared.speed }
        else { stored = SettingsStore.shared.duration }
        apply(stored, slider: slider, field: field, stepper: stepper)
        applyingControls = false
    }

    private func prepareCheck(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.font = .systemFont(ofSize: 13)
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func prepareKey(_ button: KeyCapButton, action: Selector) {
        button.target = self
        button.action = action
    }

    private func labeledRow(_ title: String, _ control: NSView, align: NSLayoutConstraint.Attribute) -> NSView {
        let label = rowLabel(title)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = align == .centerY ? .centerY : .top
        row.spacing = 18
        label.widthAnchor.constraint(equalToConstant: 148).isActive = true
        return row
    }

    private func keyRow(_ title: String, _ button: KeyCapButton, _ caption: String) -> NSView {
        let label = rowLabel(title)
        label.widthAnchor.constraint(equalToConstant: 148).isActive = true
        let note = captionLabel(caption)
        let column = NSStackView(views: [button, note])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        let row = NSStackView(views: [label, column])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 18
        note.leadingAnchor.constraint(equalTo: button.leadingAnchor).isActive = true
        return row
    }

    private func makeSliderRow(
        _ slider: NSSlider,
        _ field: NSTextField,
        _ stepper: NSStepper,
        title: String,
        caption: String,
        min: Double,
        max: Double,
        increment: Double,
        action: Selector
    ) -> NSView {
        slider.minValue = min
        slider.maxValue = max
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = action

        field.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        field.alignment = .center
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.formatter = decimalFormatter
        field.controlSize = .regular

        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = increment
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = action

        let line = NSStackView(views: [slider, field, stepper])
        line.orientation = .horizontal
        line.alignment = .centerY
        line.spacing = 8
        field.widthAnchor.constraint(equalToConstant: 72).isActive = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let note = captionLabel(caption)
        let column = NSStackView(views: [line, note])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 3

        let label = rowLabel(title)
        let row = NSView()
        label.translatesAutoresizingMaskIntoConstraints = false
        column.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        row.addSubview(column)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.widthAnchor.constraint(equalToConstant: 148),
            label.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            column.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            column.topAnchor.constraint(equalTo: row.topAnchor),
            column.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            note.leadingAnchor.constraint(equalTo: slider.leadingAnchor)
        ])
        return row
    }

    private func rowLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func captionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 420
        return label
    }
}
