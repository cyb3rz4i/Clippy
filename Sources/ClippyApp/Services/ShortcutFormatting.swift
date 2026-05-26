import AppKit
import ClippyCore

enum ShortcutFormatting {
    static func shortcut(from event: NSEvent) -> GlobalShortcut? {
        let carbonModifiers = carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            return nil
        }

        let keyCode = UInt32(event.keyCode)
        let keyName = keyName(for: event)
        let displayName = displayName(carbonModifiers: carbonModifiers, keyName: keyName)
        return GlobalShortcut(
            keyCode: keyCode,
            carbonModifiers: carbonModifiers,
            displayName: displayName
        )
    }

    static func displayName(for shortcut: GlobalShortcut) -> String {
        shortcut.displayName
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) {
            result |= GlobalShortcutModifier.command
        }
        if flags.contains(.shift) {
            result |= GlobalShortcutModifier.shift
        }
        if flags.contains(.option) {
            result |= GlobalShortcutModifier.option
        }
        if flags.contains(.control) {
            result |= GlobalShortcutModifier.control
        }
        return result
    }

    private static func displayName(carbonModifiers: UInt32, keyName: String) -> String {
        var pieces: [String] = []
        if carbonModifiers & GlobalShortcutModifier.command != 0 {
            pieces.append("Command")
        }
        if carbonModifiers & GlobalShortcutModifier.shift != 0 {
            pieces.append("Shift")
        }
        if carbonModifiers & GlobalShortcutModifier.control != 0 {
            pieces.append("Control")
        }
        if carbonModifiers & GlobalShortcutModifier.option != 0 {
            pieces.append("Option")
        }
        pieces.append(keyName.uppercased())
        return pieces.joined(separator: " ")
    }

    private static func keyName(for event: NSEvent) -> String {
        if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            return characters.uppercased()
        }

        return "Key \(event.keyCode)"
    }
}
