import AppKit
import CoreGraphics

enum WindowLocator {
    /// Owner of the topmost normal window under a CGEvent point (origin at the top-left of the main display).
    static func ownerPID(at point: CGPoint) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        for window in windows {
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if layer != 0 { continue }
            let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            if alpha < 0.05 { continue }
            guard let bounds = window[kCGWindowBounds as String] as? NSDictionary else { continue }
            var rect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(bounds, &rect), rect.contains(point) else { continue }
            let pid = pid_t((window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0)
            if pid == 0 || pid == selfPID { continue }
            return pid
        }
        return nil
    }
}
