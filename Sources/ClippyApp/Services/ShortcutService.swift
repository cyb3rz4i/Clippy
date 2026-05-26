import Carbon.HIToolbox
import ClippyCore
import Foundation

@MainActor
final class ShortcutService {
    enum ShortcutIdentifier: UInt32 {
        case showHistory = 1
        case pasteLatest = 2
        case pauseCapture = 3

        var displayName: String {
            switch self {
            case .showHistory:
                "Show clipboard history"
            case .pasteLatest:
                "Paste latest item"
            case .pauseCapture:
                "Pause or resume capture"
            }
        }
    }

    struct RegistrationFailure: Equatable {
        var action: ShortcutIdentifier
        var shortcut: GlobalShortcut
        var status: OSStatus
    }

    struct RegistrationResult: Equatable {
        var failures: [RegistrationFailure]

        var succeeded: Bool {
            failures.isEmpty
        }
    }

    private let signature: OSType = 0x434C4950
    private var hotKeyRefs: [UInt32: EventHotKeyRef?] = [:]
    private var eventHandler: EventHandlerRef?

    private var onShowHistory: (() -> Void)?
    private var onPasteLatest: (() -> Void)?
    private var onPauseCapture: (() -> Void)?

    init() {
        installEventHandler()
    }

    @discardableResult
    func register(
        showHistory: GlobalShortcut,
        pasteLatest: GlobalShortcut,
        pauseCapture: GlobalShortcut,
        onShowHistory: @escaping () -> Void,
        onPasteLatest: @escaping () -> Void,
        onPauseCapture: @escaping () -> Void
    ) -> RegistrationResult {
        self.onShowHistory = onShowHistory
        self.onPasteLatest = onPasteLatest
        self.onPauseCapture = onPauseCapture

        unregisterAll()

        var failures: [RegistrationFailure] = []
        if let status = register(showHistory, id: .showHistory) {
            failures.append(RegistrationFailure(action: .showHistory, shortcut: showHistory, status: status))
        }
        if let status = register(pasteLatest, id: .pasteLatest) {
            failures.append(RegistrationFailure(action: .pasteLatest, shortcut: pasteLatest, status: status))
        }
        if let status = register(pauseCapture, id: .pauseCapture) {
            failures.append(RegistrationFailure(action: .pauseCapture, shortcut: pauseCapture, status: status))
        }

        return RegistrationResult(failures: failures)
    }

    private func register(_ shortcut: GlobalShortcut, id: ShortcutIdentifier) -> OSStatus? {
        let hotKeyID = EventHotKeyID(signature: signature, id: id.rawValue)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            UInt32(shortcut.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotKeyRefs[id.rawValue] = hotKeyRef
            return nil
        }

        return status
    }

    private func unregisterAll() {
        for ref in hotKeyRefs.values {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event,
                      let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return status
                }

                let service = Unmanaged<ShortcutService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.handleHotKey(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
    }

    private func handleHotKey(id: UInt32) {
        switch ShortcutIdentifier(rawValue: id) {
        case .showHistory:
            onShowHistory?()
        case .pasteLatest:
            onPasteLatest?()
        case .pauseCapture:
            onPauseCapture?()
        case nil:
            break
        }
    }
}
