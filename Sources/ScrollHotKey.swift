import AppKit
import CoreGraphics

struct ScrollHotKey: Equatable, Sendable {
    static let modifierOnly: UInt16 = 0xFFFF

    var keyCode: UInt16
    var modifiers: UInt

    static let option = ScrollHotKey(keyCode: modifierOnly, modifiers: NSEvent.ModifierFlags.option.rawValue)
    static let shift = ScrollHotKey(keyCode: modifierOnly, modifiers: NSEvent.ModifierFlags.shift.rawValue)
    static let command = ScrollHotKey(keyCode: modifierOnly, modifiers: NSEvent.ModifierFlags.command.rawValue)

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection([.command, .option, .shift, .control])
    }

    func matches(flags: CGEventFlags, pressedKeys: Set<UInt16>) -> Bool {
        let mods = modifierFlags
        if mods.contains(.option), !flags.contains(.maskAlternate) { return false }
        if mods.contains(.shift), !flags.contains(.maskShift) { return false }
        if mods.contains(.command), !flags.contains(.maskCommand) { return false }
        if mods.contains(.control), !flags.contains(.maskControl) { return false }
        if keyCode == Self.modifierOnly {
            return !mods.isEmpty
        }
        return pressedKeys.contains(keyCode)
    }

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        let mods = modifierFlags
        if mods.contains(.shift) { flags.insert(.maskShift) }
        if mods.contains(.option) { flags.insert(.maskAlternate) }
        if mods.contains(.command) { flags.insert(.maskCommand) }
        if mods.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    var title: String {
        let mods = modifierFlags
        if keyCode == Self.modifierOnly {
            switch mods {
            case .option: return "⌥ Option"
            case .shift: return "⇧ Shift"
            case .command: return "⌘ Command"
            case .control: return "⌃ Control"
            default: break
            }
        }
        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        if keyCode != Self.modifierOnly {
            parts.append(Self.keyName(keyCode))
        }
        return parts.joined()
    }

    static func keyName(_ code: UInt16) -> String {
        if let letter = ansiNames[code] { return letter }
        switch code {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(code)"
        }
    }

    private static let ansiNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: "."
    ]
}
