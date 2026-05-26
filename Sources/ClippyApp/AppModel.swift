import AppKit
import ClippyCore
import Combine
import UniformTypeIdentifiers

enum MenuBarVisualState {
    case active
    case paused
    case setupNeeded
}

enum PanelMode {
    case history
    case settings
}

private enum ShortcutPreference {
    case showHistory
    case pasteLatest
    case pauseCapture

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

@MainActor
final class AppModel: ObservableObject {
    let store: ClipboardStore
    let imageStorage: ImageStorage
    let monitor: ClipboardMonitor
    let pasteService: PasteService
    let shortcutService: ShortcutService
    let launchAtLoginService: LaunchAtLoginService

    @Published var query = ""
    @Published var selectedIndex = 0
    @Published var toastMessage: String?
    @Published var previousApplication: NSRunningApplication?
    @Published var panelMode: PanelMode = .history

    var showPanel: (() -> Void)?
    var hidePanel: (() -> Void)?
    var togglePanel: (() -> Void)?

    private var cancellables: Set<AnyCancellable> = []

    init(storageDirectory: URL? = nil) {
        let store = ClipboardStore(storageDirectory: storageDirectory)
        self.store = store
        self.imageStorage = ImageStorage(
            baseDirectory: store.storageDirectory.appendingPathComponent("ImagePayloads", isDirectory: true)
        )
        self.monitor = ClipboardMonitor(store: store, imageStorage: imageStorage)
        self.pasteService = PasteService(store: store, monitor: monitor)
        self.shortcutService = ShortcutService()
        self.launchAtLoginService = LaunchAtLoginService()

        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var filteredItems: [ClipboardItem] {
        store.search(query)
    }

    var selectedItem: ClipboardItem? {
        let items = filteredItems
        guard items.indices.contains(selectedIndex) else {
            return items.first
        }
        return items[selectedIndex]
    }

    var menuBarState: MenuBarVisualState {
        if !store.preferences.hasCompletedOnboarding || !store.preferences.captureEnabled {
            return .setupNeeded
        }
        if store.preferences.capturePaused {
            return .paused
        }
        return .active
    }

    var isAccessibilityTrusted: Bool {
        pasteService.isAccessibilityTrusted
    }

    func start() {
        let result = registerShortcuts()
        if let failure = result.failures.first {
            toastMessage = "\(failure.action.displayName) shortcut is unavailable"
        }
        monitor.start()
        syncLaunchAtLoginState()
    }

    func requestShowPanel() {
        rememberPreviousApplication()
        panelMode = .history
        showPanel?()
    }

    func requestTogglePanel() {
        rememberPreviousApplication()
        panelMode = .history
        togglePanel?()
    }

    func requestOpenSettings() {
        panelMode = .settings
        showPanel?()
    }

    func requestShowHistory() {
        panelMode = .history
        showPanel?()
    }

    func selectNext() {
        let count = filteredItems.count
        guard count > 0 else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(selectedIndex + 1, count - 1)
    }

    func selectPrevious() {
        selectedIndex = max(selectedIndex - 1, 0)
    }

    func selectItem(at index: Int) {
        let items = filteredItems
        guard items.indices.contains(index) else {
            return
        }
        selectedIndex = index
        choose(items[index])
    }

    func chooseSelectedItem() {
        guard let selectedItem else {
            return
        }
        choose(selectedItem)
    }

    func choose(_ item: ClipboardItem) {
        let result = pasteService.copy(
            item,
            autoPaste: store.preferences.autoPasteWhenAllowed,
            previousApplication: previousApplication
        )
        store.markUsed(id: item.id)
        toastMessage = result.message
        hidePanel?()
    }

    func pasteLatest() {
        guard let item = store.mostRecentUnpinnedAwareItem() else {
            toastMessage = "No clipboard history yet"
            return
        }
        choose(item)
    }

    func completeOnboarding() {
        store.updatePreferences {
            $0.hasCompletedOnboarding = true
            $0.captureEnabled = true
            $0.capturePaused = false
        }
        monitor.start()
        toastMessage = "Clipboard history is on"
    }

    func setCaptureEnabled(_ isEnabled: Bool) {
        store.updatePreferences {
            $0.captureEnabled = isEnabled
            if isEnabled {
                $0.hasCompletedOnboarding = true
            }
        }
        monitor.start()
    }

    func toggleCapturePaused() {
        setCapturePaused(!store.preferences.capturePaused)
    }

    func setCapturePaused(_ isPaused: Bool) {
        store.updatePreferences {
            $0.capturePaused = isPaused
        }
        toastMessage = store.preferences.capturePaused ? "Capture paused" : "Capture resumed"
    }

    func setAutoPaste(_ isEnabled: Bool) {
        store.updatePreferences {
            $0.autoPasteWhenAllowed = isEnabled
        }
        if isEnabled {
            pasteService.requestAccessibilityPermission()
        }
    }

    func setHistoryLimit(_ limit: Double) {
        store.updatePreferences {
            $0.historyLimit = Int(limit)
        }
    }

    func setShowHistoryShortcut(_ shortcut: GlobalShortcut) {
        setShortcut(shortcut, for: .showHistory)
    }

    func setPasteLatestShortcut(_ shortcut: GlobalShortcut) {
        setShortcut(shortcut, for: .pasteLatest)
    }

    func setPauseCaptureShortcut(_ shortcut: GlobalShortcut) {
        setShortcut(shortcut, for: .pauseCapture)
    }

    func resetShortcutsToDefaults() {
        let previous = store.preferences
        store.updatePreferences {
            $0.showHistoryShortcut = .showHistoryDefault
            $0.pasteLatestShortcut = .pasteLatestDefault
            $0.pauseCaptureShortcut = .pauseCaptureDefault
        }

        let result = registerShortcuts()
        if let failure = result.failures.first {
            store.updatePreferences { preferences in
                preferences = previous
            }
            _ = registerShortcuts()
            toastMessage = "Default shortcut unavailable: \(failure.shortcut.displayName)"
        } else {
            toastMessage = "Shortcuts reset"
        }
    }

    func clearHistory() {
        store.clearHistory()
        toastMessage = "History cleared"
    }

    func clearUnpinnedHistory() {
        store.clearHistory(keepingPinned: true)
        toastMessage = "Unpinned history cleared"
    }

    func delete(_ item: ClipboardItem) {
        store.delete(id: item.id)
        selectedIndex = min(selectedIndex, max(filteredItems.count - 1, 0))
    }

    func togglePinned(_ item: ClipboardItem) {
        store.setPinned(!item.isPinned, id: item.id)
    }

    func addFrontmostAppToExclusions() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else {
            toastMessage = "No eligible frontmost app"
            return
        }

        store.updatePreferences {
            $0.excludedBundleIDs.insert(bundleID)
        }
        toastMessage = "\(app.localizedName ?? bundleID) excluded"
    }

    func chooseAppForExclusion() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to exclude"
        panel.message = "Clippy will not capture clipboard history while the selected app is frontmost."
        panel.prompt = "Exclude App"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            Task { @MainActor in
                self?.addExcludedApp(at: url)
            }
        }
    }

    func addExcludedApp(at url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            toastMessage = "Could not read that app"
            return
        }

        store.updatePreferences {
            $0.excludedBundleIDs.insert(bundleID)
        }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        toastMessage = "\(name) excluded"
    }

    func removeExcludedBundleID(_ bundleID: String) {
        store.updatePreferences {
            $0.excludedBundleIDs.remove(bundleID)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let didChange = launchAtLoginService.setEnabled(enabled)
        store.updatePreferences {
            $0.launchAtLogin = didChange ? enabled : $0.launchAtLogin
        }
        toastMessage = didChange
            ? (enabled ? "Launch at login enabled" : "Launch at login disabled")
            : "Could not update launch at login"
    }

    func requestAccessibilityPermission() {
        pasteService.requestAccessibilityPermission()
        toastMessage = "Accessibility request sent"
    }

    private func rememberPreviousApplication() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApplication = current
        }
    }

    @discardableResult
    private func registerShortcuts() -> ShortcutService.RegistrationResult {
        shortcutService.register(
            showHistory: store.preferences.showHistoryShortcut,
            pasteLatest: store.preferences.pasteLatestShortcut,
            pauseCapture: store.preferences.pauseCaptureShortcut,
            onShowHistory: { [weak self] in self?.requestTogglePanel() },
            onPasteLatest: { [weak self] in self?.pasteLatest() },
            onPauseCapture: { [weak self] in self?.toggleCapturePaused() }
        )
    }

    private func setShortcut(_ shortcut: GlobalShortcut, for action: ShortcutPreference) {
        guard shortcut.hasPrimaryModifier else {
            toastMessage = "Use Command, Control, or Option with a key"
            return
        }

        if let duplicate = duplicateShortcutAction(for: shortcut, excluding: action) {
            toastMessage = "Already used by \(duplicate.displayName)"
            return
        }

        let previous = store.preferences
        store.updatePreferences { preferences in
            switch action {
            case .showHistory:
                preferences.showHistoryShortcut = shortcut
            case .pasteLatest:
                preferences.pasteLatestShortcut = shortcut
            case .pauseCapture:
                preferences.pauseCaptureShortcut = shortcut
            }
        }

        let result = registerShortcuts()
        if let failure = result.failures.first {
            store.updatePreferences { preferences in
                preferences = previous
            }
            _ = registerShortcuts()
            toastMessage = "\(failure.shortcut.displayName) is unavailable"
        } else {
            toastMessage = "\(action.displayName) shortcut updated"
        }
    }

    private func duplicateShortcutAction(for shortcut: GlobalShortcut, excluding action: ShortcutPreference) -> ShortcutPreference? {
        let preferences = store.preferences
        let pairs: [(ShortcutPreference, GlobalShortcut)] = [
            (.showHistory, preferences.showHistoryShortcut),
            (.pasteLatest, preferences.pasteLatestShortcut),
            (.pauseCapture, preferences.pauseCaptureShortcut)
        ]

        return pairs.first { candidateAction, candidateShortcut in
            candidateAction != action && candidateShortcut.hasSameKeyCombination(as: shortcut)
        }?.0
    }

    private func syncLaunchAtLoginState() {
        let enabled = launchAtLoginService.isEnabled
        if enabled != store.preferences.launchAtLogin {
            store.updatePreferences {
                $0.launchAtLogin = enabled
            }
        }
    }
}
