import AppKit
import CoreGraphics
import Darwin
import QuartzCore

/// Spreads one wheel notch across several frames and posts the pieces straight to the target app.
final class WheelSmoother: NSObject {
    private var displayLink: CADisplayLink?
    private var remainingY: Double = 0
    private var remainingX: Double = 0
    private var gestureOpen = false
    private var lastTimestamp: CFTimeInterval?
    private var location: CGPoint = .zero
    private var flags: CGEventFlags = []
    private var pid: pid_t = 0
    private var step: Double = 48
    private var scrollCount: Int64 = 0

    func absorb(
        pixelsY: Double,
        pixelsX: Double,
        step: Double,
        location: CGPoint,
        flags: CGEventFlags,
        pid: pid_t
    ) {
        self.step = step
        self.location = location
        self.pid = pid
        self.flags = flags
        remainingY = ScrollMath.clampResidual(remainingY + pixelsY, step: step)
        remainingX = ScrollMath.clampResidual(remainingX + pixelsX, step: step)
        ensureLink()
        displayLink?.isPaused = false
    }

    func cancel() {
        let wasOpen = gestureOpen
        remainingY = 0
        remainingX = 0
        gestureOpen = false
        lastTimestamp = nil
        displayLink?.isPaused = true
        if wasOpen {
            post(dy: 0, dx: 0, phase: Self.phaseEnded)
        }
    }

    func stop() {
        cancel()
        displayLink?.invalidate()
        displayLink = nil
    }

    private func ensureLink() {
        if displayLink != nil { return }
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main
        guard let screen else { return }
        let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt: Double
        if let lastTimestamp {
            dt = min(max(link.timestamp - lastTimestamp, 0.001), 0.05)
        } else {
            dt = min(max(link.duration > 0 ? link.duration : 1.0 / 60.0, 0.001), 0.05)
        }
        lastTimestamp = link.timestamp

        let settings = SettingsStore.shared
        let tau = ScrollMath.timeConstant(duration: settings.duration, speed: settings.speed)
        let (dy, leftY) = ScrollMath.deliver(remaining: remainingY, dt: dt, tau: tau)
        let (dx, leftX) = ScrollMath.deliver(remaining: remainingX, dt: dt, tau: tau)
        remainingY = leftY
        remainingX = leftX

        let done = leftY == 0 && leftX == 0
        let phase: Int64 = done ? Self.phaseEnded : (gestureOpen ? Self.phaseChanged : Self.phaseBegan)
        if !done {
            gestureOpen = true
        }
        if dy != 0 || dx != 0 || phase == Self.phaseEnded {
            post(dy: dy, dx: dx, phase: phase)
        }
        if done {
            gestureOpen = false
            lastTimestamp = nil
            link.isPaused = true
        }
    }

    private func post(dy: Double, dx: Double, phase: Int64) {
        guard let source = CGEventSource(stateID: .privateState) else { return }
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: Self.whole(dy),
            wheel2: Self.whole(dx),
            wheel3: 0
        ) else { return }

        event.location = location
        event.flags = flags
        event.timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        event.setIntegerValueField(.eventSourceUserData, value: ScrollEngine.syntheticMarker)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: dy)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: dx)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(Self.whole(dy)))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(Self.whole(dx)))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 0)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        scrollCount &+= 1
        event.setIntegerValueField(.scrollWheelEventScrollCount, value: scrollCount)

        if pid > 0 {
            event.postToPid(pid)
        } else {
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    private static func whole(_ value: Double) -> Int32 {
        let rounded = value.rounded()
        if rounded >= Double(Int32.max) { return Int32.max }
        if rounded <= Double(Int32.min) { return Int32.min }
        return Int32(rounded)
    }

    private static let phaseBegan: Int64 = 1
    private static let phaseChanged: Int64 = 4
    private static let phaseEnded: Int64 = 8
}
