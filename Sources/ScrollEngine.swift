import AppKit
import ApplicationServices
import CoreGraphics
import os

private let scrollLog = Logger(subsystem: "app.mackey.mouse", category: "scroll")

/// Scroll intercept patterned after Caldis/Mos:
/// scroll-only defaultTap, reverse on the live event, suppress + post when smoothing.
final class ScrollEngine: @unchecked Sendable {
    static let syntheticMarker: Int64 = 0x4D4B_5945_5931

    private let smoother = WheelSmoother()
    private var scrollPort: CFMachPort?
    private var scrollSource: CFRunLoopSource?
    private var auxPort: CFMachPort?
    private var auxSource: CFRunLoopSource?
    private var pressedKeys = Set<UInt16>()
    private var keeper: Timer?
    private var starting = false
    private var lastAttempt: CFAbsoluteTime = 0
    private var didLogTapFailure = false

    var isTapRunning: Bool {
        guard let scrollPort else { return false }
        return CGEvent.tapIsEnabled(tap: scrollPort)
    }

    func startIfNeeded() {
        guard SettingsStore.shared.enabled else { return }
        if let scrollPort {
            if !CGEvent.tapIsEnabled(tap: scrollPort) {
                CGEvent.tapEnable(tap: scrollPort, enable: true)
            }
            return
        }
        start()
    }

    func start() {
        guard scrollPort == nil, !starting else { return }
        let now = CFAbsoluteTimeGetCurrent()
        // Avoid hammering tapCreate while Accessibility is still settling.
        guard now - lastAttempt > 1.5 else { return }
        lastAttempt = now
        starting = true
        installTaps()
        starting = false
    }

    func stop() {
        keeper?.invalidate()
        keeper = nil
        smoother.stop()
        tearDownPorts()
        AccessibilityPermission.tapActive = false
        NotificationCenter.default.post(name: .mackeyAccessChanged, object: nil)
    }

    private func installTaps() {
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        // Mos: scroll mask is ONLY scrollWheel.
        let scrollMask = eventMask(.scrollWheel)
        let locations: [(CGEventTapLocation, CGEventTapPlacement, String)] = [
            (.cgAnnotatedSessionEventTap, .tailAppendEventTap, "annotated/tail"),
            (.cgSessionEventTap, .tailAppendEventTap, "session/tail"),
            (.cghidEventTap, .tailAppendEventTap, "hid/tail")
        ]

        var installed: CFMachPort?
        var used = ""
        for (location, place, name) in locations {
            if let port = CGEvent.tapCreate(
                tap: location,
                place: place,
                options: .defaultTap,
                eventsOfInterest: scrollMask,
                callback: mackeyScrollTapCallback,
                userInfo: userInfo
            ) {
                installed = port
                used = name
                break
            }
        }

        guard let port = installed else {
            if !didLogTapFailure {
                didLogTapFailure = true
                scrollLog.error(
                    "tapCreate failed (AXIsProcessTrusted=\(AXIsProcessTrusted(), privacy: .public)). Settings toggle can be stale after rebuild."
                )
            }
            AccessibilityPermission.tapActive = false
            NotificationCenter.default.post(name: .mackeyAccessChanged, object: nil)
            return
        }
        didLogTapFailure = false

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        scrollPort = port
        scrollSource = source

        let auxMask = eventMask(.keyDown) | eventMask(.keyUp) | eventMask(.flagsChanged)
            | eventMask(.leftMouseDown) | eventMask(.rightMouseDown) | eventMask(.otherMouseDown)
        if let aux = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: auxMask,
            callback: mackeyAuxTapCallback,
            userInfo: userInfo
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: auxMask,
            callback: mackeyAuxTapCallback,
            userInfo: userInfo
        ) {
            let auxSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, aux, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), auxSource, .commonModes)
            CGEvent.tapEnable(tap: aux, enable: true)
            auxPort = aux
            self.auxSource = auxSource
        }

        AccessibilityPermission.tapActive = true
        beginKeeper()
        scrollLog.error("Scroll tap installed at \(used, privacy: .public)")
        NotificationCenter.default.post(name: .mackeyAccessChanged, object: nil)
    }

    private func tearDownPorts() {
        if let scrollPort {
            CGEvent.tapEnable(tap: scrollPort, enable: false)
            CFMachPortInvalidate(scrollPort)
        }
        if let auxPort {
            CGEvent.tapEnable(tap: auxPort, enable: false)
            CFMachPortInvalidate(auxPort)
        }
        if let scrollSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), scrollSource, .commonModes)
        }
        if let auxSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), auxSource, .commonModes)
        }
        scrollPort = nil
        scrollSource = nil
        auxPort = nil
        auxSource = nil
    }

    fileprivate func handleScroll(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let scrollPort {
                CGEvent.tapEnable(tap: scrollPort, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        let settings = SettingsStore.shared
        guard settings.enabled else {
            return Unmanaged.passUnretained(event)
        }

        let sample = Self.sample(from: event)
        guard ScrollMath.isWheel(sample, detection: .gesture) else {
            smoother.cancel()
            return Unmanaged.passUnretained(event)
        }

        let dash = settings.dashKey.matches(flags: event.flags, pressedKeys: pressedKeys)
        let toggle = settings.toggleKey.matches(flags: event.flags, pressedKeys: pressedKeys)

        let hasY = ScrollMath.usableY(sample) != 0
        let hasX = ScrollMath.usableX(sample) != 0
        if !hasY, !hasX {
            return Unmanaged.passUnretained(event)
        }

        // Edit the live event in place and let it continue — never suppress.
        // Suppress + repost was what killed scrolling when a repost failed to land.
        if settings.reverse {
            if hasY { negateAxis(event, vertical: true) }
            if hasX { negateAxis(event, vertical: false) }
        }
        if dash {
            scaleAxis(event, vertical: true, factor: ScrollMath.dashMultiplier)
            scaleAxis(event, vertical: false, factor: ScrollMath.dashMultiplier)
            event.flags.subtract(settings.dashKey.cgFlags)
        }
        if toggle, hasY, !hasX {
            swapAxes(event)
            event.flags.subtract(settings.toggleKey.cgFlags)
        }
        return Unmanaged.passUnretained(event)
    }

    fileprivate func handleAux(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let auxPort {
                CGEvent.tapEnable(tap: auxPort, enable: true)
            }
            return
        }

        if type == .keyDown || type == .keyUp || type == .flagsChanged {
            noteKey(type: type, event: event)
            return
        }

        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            smoother.cancel()
        }
    }

    private func noteKey(type: CGEventType, event: CGEvent) {
        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyDown {
            pressedKeys.insert(code)
        } else if type == .keyUp {
            pressedKeys.remove(code)
        }
        if SettingsStore.shared.blockKey.matches(flags: event.flags, pressedKeys: pressedKeys) {
            smoother.cancel()
        }
    }

    private func beginKeeper() {
        keeper?.invalidate()
        keeper = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard SettingsStore.shared.enabled else { return }
            if let scrollPort = self.scrollPort {
                if !CGEvent.tapIsEnabled(tap: scrollPort) {
                    CGEvent.tapEnable(tap: scrollPort, enable: true)
                    if !CGEvent.tapIsEnabled(tap: scrollPort) {
                        self.stop()
                        self.start()
                    }
                }
            } else {
                self.start()
            }
        }
    }

    private static func sample(from event: CGEvent) -> ScrollSample {
        ScrollSample(
            lineY: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
            lineX: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
            pointY: event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1),
            pointX: event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2),
            fixedY: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
            fixedX: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
            phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            scrollCount: event.getIntegerValueField(.scrollWheelEventScrollCount),
            continuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        )
    }

    private func negateAxis(_ event: CGEvent, vertical: Bool) {
        if vertical {
            let line = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let point = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -line)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -point)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed)
            HIDScroll.multiply(event: event, y: -1, x: 1)
        } else {
            let line = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let point = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -line)
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -point)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed)
            HIDScroll.multiply(event: event, y: 1, x: -1)
        }
    }

    private func scaleAxis(_ event: CGEvent, vertical: Bool, factor: Double) {
        guard factor != 1 else { return }
        if vertical {
            let line = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) * factor
            let point = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) * factor
            let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) * factor
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(line.rounded()))
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: point)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixed)
            HIDScroll.multiply(event: event, y: factor, x: 1)
        } else {
            let line = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)) * factor
            let point = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2) * factor
            let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) * factor
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(line.rounded()))
            event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: point)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixed)
            HIDScroll.multiply(event: event, y: 1, x: factor)
        }
    }

    private func swapAxes(_ event: CGEvent) {
        let lineY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let lineX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let pointY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let pointX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        let fixedY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixedX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: lineX)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: lineY)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: pointX)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: pointY)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixedX)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixedY)
        HIDScroll.swapAxes(event: event)
    }

    private func eventMask(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << CGEventMask(type.rawValue)
    }
}

private func mackeyScrollTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
    return engine.handleScroll(type: type, event: event)
}

private func mackeyAuxTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<ScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
    engine.handleAux(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
