import AppKit
import ClippyCore
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    var shortcut: GlobalShortcut
    var onChange: (GlobalShortcut) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.shortcut = shortcut
        button.onChange = onChange
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.shortcut = shortcut
        nsView.onChange = onChange
    }
}

final class RecorderButton: NSButton {
    var shortcut: GlobalShortcut = .showHistoryDefault {
        didSet {
            if !isRecording {
                title = ShortcutFormatting.displayName(for: shortcut)
            }
        }
    }

    var onChange: ((GlobalShortcut) -> Void)?
    private var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        controlSize = .large
        setButtonType(.momentaryPushIn)
        title = ShortcutFormatting.displayName(for: shortcut)
        target = self
        action = #selector(startRecording)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func startRecording() {
        isRecording = true
        title = "Type shortcut"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            isRecording = false
            title = ShortcutFormatting.displayName(for: shortcut)
            return
        }

        guard let shortcut = ShortcutFormatting.shortcut(from: event) else {
            NSSound.beep()
            return
        }

        isRecording = false
        self.shortcut = shortcut
        onChange?(shortcut)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        title = ShortcutFormatting.displayName(for: shortcut)
        return super.resignFirstResponder()
    }
}
