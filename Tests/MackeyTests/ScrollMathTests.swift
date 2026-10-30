import CoreGraphics
import Testing
@testable import Mackey

private func sample(
    lineY: Int64 = 0,
    lineX: Int64 = 0,
    pointY: Double = 0,
    pointX: Double = 0,
    fixedY: Double = 0,
    fixedX: Double = 0,
    phase: Int64 = 0,
    momentumPhase: Int64 = 0,
    scrollCount: Int64 = 0,
    continuous: Bool = false
) -> ScrollSample {
    ScrollSample(
        lineY: lineY,
        lineX: lineX,
        pointY: pointY,
        pointX: pointX,
        fixedY: fixedY,
        fixedX: fixedX,
        phase: phase,
        momentumPhase: momentumPhase,
        scrollCount: scrollCount,
        continuous: continuous
    )
}

@Test func discreteNotchIsAWheel() {
    let notch = sample(lineY: -1, continuous: false)
    #expect(ScrollMath.isWheel(notch, detection: .gesture))
    let action = ScrollMath.action(
        for: notch,
        reverse: true,
        smoothing: true,
        step: 20,
        dash: false,
        toggle: false,
        block: false
    )
    #expect(action == .smooth(pixelsY: 20, pixelsX: 0, toggleHandled: false))
}

@Test func gesturePhaseIsNotAWheel() {
    let trackpad = sample(pointY: 4, phase: 4, continuous: true)
    let action = ScrollMath.action(
        for: trackpad,
        reverse: true,
        smoothing: true,
        step: 40,
        dash: false,
        toggle: false,
        block: false
    )
    #expect(action == .pass)
}

@Test func scrollCountIsNotAWheel() {
    #expect(!ScrollMath.isWheel(sample(scrollCount: 2, continuous: true), detection: .gesture))
}

@Test func momentumIsNotAWheel() {
    #expect(!ScrollMath.isWheel(sample(momentumPhase: 2, continuous: true), detection: .gesture))
}

@Test func discreteWheelIsReversedAndSmoothed() {
    let action = ScrollMath.action(
        for: sample(lineY: 1, pointY: 10),
        reverse: true,
        smoothing: true,
        step: 40,
        dash: false,
        toggle: false,
        block: false
    )
    #expect(action == .smooth(pixelsY: -40, pixelsX: 0, toggleHandled: false))
}

@Test func dashMultipliesStep() {
    let action = ScrollMath.action(
        for: sample(lineY: 1),
        reverse: false,
        smoothing: true,
        step: 10,
        dash: true,
        toggle: false,
        block: false
    )
    #expect(action == .smooth(pixelsY: 40, pixelsX: 0, toggleHandled: false))
}

@Test func toggleTurnsVerticalIntoHorizontal() {
    let action = ScrollMath.action(
        for: sample(lineY: -1),
        reverse: true,
        smoothing: true,
        step: 30,
        dash: false,
        toggle: true,
        block: false
    )
    #expect(action == .smooth(pixelsY: 0, pixelsX: 30, toggleHandled: true))
}

@Test func toggleDoesNotSwapWhenHorizontalAlreadyPresent() {
    let action = ScrollMath.action(
        for: sample(lineY: 1, lineX: 1),
        reverse: true,
        smoothing: true,
        step: 10,
        dash: false,
        toggle: true,
        block: false
    )
    #expect(action == .smooth(pixelsY: -10, pixelsX: -10, toggleHandled: false))
}

@Test func blockDisablesSmoothingButKeepsReverse() {
    let action = ScrollMath.action(
        for: sample(lineY: 1),
        reverse: true,
        smoothing: true,
        step: 40,
        dash: false,
        toggle: false,
        block: true
    )
    #expect(action == .reverse)
}

@Test func discreteModeIgnoresContinuousEvents() {
    let highResolution = sample(pointY: 3, continuous: true)
    #expect(!ScrollMath.isWheel(highResolution, detection: .discrete))
    #expect(ScrollMath.isWheel(highResolution, detection: .gesture))
}

@Test func smoothOffOnlyReverses() {
    let action = ScrollMath.action(
        for: sample(lineY: 1),
        reverse: true,
        smoothing: false,
        step: 40,
        dash: false,
        toggle: false,
        block: false
    )
    #expect(action == .reverse)
}

@Test func noReverseAndNoSmoothPassesTheEvent() {
    let action = ScrollMath.action(
        for: sample(lineY: 1),
        reverse: false,
        smoothing: false,
        step: 40,
        dash: false,
        toggle: false,
        block: false
    )
    #expect(action == .pass)
}

@Test func decaySeriesSumsToTheOriginalDistance() {
    var left = 100.0
    var sum = 0.0
    for _ in 0..<800 {
        let step = ScrollMath.deliver(remaining: left, dt: 1.0 / 120.0, tau: 0.18)
        sum += step.delivered
        left = step.left
        if left == 0 { break }
    }
    #expect(left == 0)
    #expect(abs(sum - 100) < 0.001)
}

@Test func residualIsCapped() {
    #expect(ScrollMath.clampResidual(10_000, step: 40) == 480)
    #expect(ScrollMath.clampResidual(-10_000, step: 40) == -480)
}

@Test func defaultsLandInTheMiddleOfTheSliders() {
    let tau = ScrollMath.timeConstant(duration: 4.35, speed: 2.7)
    #expect(tau > 0.08 && tau < 0.25)
    #expect(SettingsStore.clampedStep(33.60) == 33.60)
    #expect(SettingsStore.clampedSpeed(2.70) == 2.70)
    #expect(SettingsStore.clampedDuration(4.35) == 4.35)
}

@Test func optionHotKeyMatchesTheAlternateFlag() {
    #expect(ScrollHotKey.option.matches(flags: .maskAlternate, pressedKeys: []))
    #expect(!ScrollHotKey.option.matches(flags: [], pressedKeys: []))
    #expect(ScrollHotKey.option.title == "⌥ Option")
    #expect(ScrollHotKey.shift.title == "⇧ Shift")
    #expect(ScrollHotKey.command.title == "⌘ Command")
}
