import AppKit
import ApplicationServices
import CoreGraphics

if CommandLine.arguments.contains("--diagnose") {
    let trusted = AXIsProcessTrusted()
    fputs("AXIsProcessTrusted=\(trusted)\n", stderr)
    fputs("executable=\(Bundle.main.executablePath ?? "?")\n", stderr)
    let mask = CGEventMask(1) << CGEventMask(CGEventType.scrollWheel.rawValue)
    let locations: [(CGEventTapLocation, String)] = [
        (.cgAnnotatedSessionEventTap, "annotated"),
        (.cgSessionEventTap, "session"),
        (.cghidEventTap, "hid")
    ]
    for (location, name) in locations {
        let port = CGEvent.tapCreate(
            tap: location,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        fputs("tapCreate \(name)/tail => \(port != nil)\n", stderr)
        if let port {
            CFMachPortInvalidate(port)
        }
    }
    exit(trusted && true ? 0 : 1)
}

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    application.delegate = delegate
    application.run()
}
