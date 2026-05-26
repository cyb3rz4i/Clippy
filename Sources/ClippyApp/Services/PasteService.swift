import ApplicationServices
import AppKit
import ClippyCore

struct PasteResult {
    var message: String
}

@MainActor
final class PasteService {
    private let store: ClipboardStore
    private let monitor: ClipboardMonitor

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
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

        guard isAccessibilityTrusted else {
            return PasteResult(message: "Copied. Enable Accessibility for auto-paste.")
        }

        previousApplication?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.sendPasteKeystroke()
        }

        return PasteResult(message: "Pasted")
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
