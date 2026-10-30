import CoreGraphics
import Foundation

enum WheelDetection: String, Sendable {
    /// Mos-style: phase / momentum / scrollCount mark a trackpad or Magic Mouse.
    case gesture
    /// Only classic line-based wheel packets (`isContinuous == 0`) are wheels.
    case discrete
}

struct ScrollSample: Equatable, Sendable {
    var lineY: Int64
    var lineX: Int64
    var pointY: Double
    var pointX: Double
    var fixedY: Double
    var fixedX: Double
    var phase: Int64
    var momentumPhase: Int64
    var scrollCount: Int64
    var continuous: Bool
}

enum WheelAction: Equatable, Sendable {
    case pass
    case reverse
    case smooth(pixelsY: Double, pixelsX: Double, toggleHandled: Bool)
}

enum ScrollMath {
    /// How much farther one notch goes while Dash is held.
    static let dashMultiplier = 4.0

    /// Same signals Mos uses in `ScrollEvent.isTrackpad`.
    static func isTrackpad(_ sample: ScrollSample, detection: WheelDetection) -> Bool {
        switch detection {
        case .gesture:
            if sample.phase != 0 || sample.momentumPhase != 0 { return true }
            if sample.scrollCount != 0 { return true }
            return false
        case .discrete:
            return sample.continuous
        }
    }

    static func isWheel(_ sample: ScrollSample, detection: WheelDetection) -> Bool {
        !isTrackpad(sample, detection: detection)
    }

    /// Prefer point deltas, then fixed-point, then line notches — same as Mos `usableValue`.
    static func usableY(_ sample: ScrollSample) -> Double {
        if sample.pointY != 0 { return sample.pointY }
        if sample.fixedY != 0 { return sample.fixedY }
        return Double(sample.lineY)
    }

    static func usableX(_ sample: ScrollSample) -> Double {
        if sample.pointX != 0 { return sample.pointX }
        if sample.fixedX != 0 { return sample.fixedX }
        return Double(sample.lineX)
    }

    /// Mos `normalize`: keep the sign, bump tiny notches up to at least `threshold`.
    static func normalize(_ value: Double, threshold: Double) -> Double {
        guard value != 0 else { return 0 }
        let magnitude = max(abs(value), threshold)
        return value > 0 ? magnitude : -magnitude
    }

    static func action(
        for sample: ScrollSample,
        detection: WheelDetection = .gesture,
        reverse: Bool,
        smoothing: Bool,
        step: Double,
        dash: Bool,
        toggle: Bool,
        block: Bool
    ) -> WheelAction {
        guard isWheel(sample, detection: detection) else { return .pass }

        var y = usableY(sample)
        var x = usableX(sample)
        if y == 0, x == 0 { return .pass }

        if reverse {
            y = -y
            x = -x
        }

        if smoothing, !block {
            let threshold = step * (dash ? dashMultiplier : 1)
            y = normalize(y, threshold: threshold)
            x = normalize(x, threshold: threshold)

            var toggleHandled = false
            if toggle, y != 0, x == 0 {
                x = y
                y = 0
                toggleHandled = true
            }
            if y == 0, x == 0 { return .pass }
            return .smooth(pixelsY: y, pixelsX: x, toggleHandled: toggleHandled)
        }

        if reverse || dash || (toggle && y != 0 && x == 0) {
            return .reverse
        }
        return .pass
    }

    /// Animation time constant. Duration lengthens the glide; speed makes it accelerate harder.
    static func timeConstant(duration: Double, speed: Double) -> Double {
        let tau = duration / max(speed, 0.15) * 0.09
        return min(max(tau, 0.02), 1.5)
    }

    /// Exponential decay. The final step snaps the leftover so the series sums to the input.
    static func deliver(remaining: Double, dt: Double, tau: Double) -> (delivered: Double, left: Double) {
        if abs(remaining) <= 0.2 {
            return (remaining, 0)
        }
        let alpha = 1 - exp(-dt / max(tau, 0.001))
        let delivered = remaining * alpha
        let left = remaining - delivered
        if abs(left) <= 0.2 {
            return (remaining, 0)
        }
        return (delivered, left)
    }

    static func clampResidual(_ value: Double, step: Double) -> Double {
        let cap = max(step, 0.1) * 12
        return min(max(value, -cap), cap)
    }
}
