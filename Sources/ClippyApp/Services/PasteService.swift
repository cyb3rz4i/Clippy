import ApplicationServices
import AppKit
import ClippyCore

struct PasteResult {
    var message: String
}

@MainActor
final class PasteService {
    private let monitor: ClipboardMonitor
    private var hasPromptedForAccessibility = false

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
    }

    @discardableResult
    func copy(
        _ item: ClipboardItem,
        autoPaste: Bool,
        previousApplication: NSRunningApplication?
    ) -> PasteResult {
        writeToPasteboard(item)

        guard autoPaste else {
            return PasteResult(message: "Copied")
        }

        guard isAccessibilityTrusted(promptIfNeeded: true) else {
            return PasteResult(message: "Copied. Enable Accessibility for auto-paste.")
        }

        previousApplication?.activate()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            sendPasteKeystroke()
        }

        return PasteResult(message: "Pasted")
    }

    private func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.payload {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .url(let url, _):
            pasteboard.writeObjects([url as NSURL])
            pasteboard.setString(url.absoluteString, forType: .string)
        case .image(let imagePayload):
            if let image = NSImage(contentsOf: imagePayload.fileURL) {
                pasteboard.writeObjects([image])
            }
        }

        monitor.markInternalChange(pasteboard.changeCount)
    }

    private func isAccessibilityTrusted(promptIfNeeded: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        guard promptIfNeeded, !hasPromptedForAccessibility else {
            return false
        }

        hasPromptedForAccessibility = true
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
