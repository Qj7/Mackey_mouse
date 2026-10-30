import CoreGraphics
import Darwin
import Foundation

/// Chrome and other Chromium apps read the embedded HID scroll, not only the CGEvent deltas.
/// These symbols are not in the public SDK. If they are missing, CGEvent negation still applies.
enum HIDScroll {
    private static let scrollX: UInt32 = 0x0006_0000
    private static let scrollY: UInt32 = 0x0006_0001

    private typealias CopyEvent = @convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?
    private typealias SetOnEvent = @convention(c) (CFTypeRef, CFTypeRef) -> Void
    private typealias GetFloat = @convention(c) (CFTypeRef, UInt32) -> Double
    private typealias SetFloat = @convention(c) (CFTypeRef, UInt32, Double) -> Void

    private static let copy: CopyEvent? = load("CGEventCopyIOHIDEvent")
    private static let writeBack: SetOnEvent? = load("CGEventSetIOHIDEvent")
    private static let get: GetFloat? = load("IOHIDEventGetFloatValue", framework: "IOKit")
    private static let set: SetFloat? = load("IOHIDEventSetFloatValue", framework: "IOKit")

    /// Multiplies the embedded HID scroll. Callers must rewrite the CGEvent deltas afterwards:
    /// writing the HID event back can restore the old CGEvent values.
    static func multiply(event: CGEvent, y: Double, x: Double) {
        guard y != 1 || x != 1 else { return }
        guard let copy, let get, let set, let writeBack else { return }
        let eventRef = event as CFTypeRef
        guard let hid = copy(eventRef)?.takeRetainedValue() else { return }
        let oldY = get(hid, scrollY)
        let oldX = get(hid, scrollX)
        guard oldY != 0 || oldX != 0 else { return }
        set(hid, scrollY, oldY * y)
        set(hid, scrollX, oldX * x)
        writeBack(eventRef, hid)
    }

    static func swapAxes(event: CGEvent) {
        guard let copy, let get, let set, let writeBack else { return }
        let eventRef = event as CFTypeRef
        guard let hid = copy(eventRef)?.takeRetainedValue() else { return }
        let oldY = get(hid, scrollY)
        let oldX = get(hid, scrollX)
        guard oldY != 0 || oldX != 0 else { return }
        set(hid, scrollY, oldX)
        set(hid, scrollX, oldY)
        writeBack(eventRef, hid)
    }

    private static func load<T>(_ name: String, framework: String? = nil) -> T? {
        if let framework {
            _ = dlopen("/System/Library/Frameworks/\(framework).framework/\(framework)", RTLD_LAZY)
        }
        // RTLD_DEFAULT is ((void *) -2). The C macro does not import into Swift.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
