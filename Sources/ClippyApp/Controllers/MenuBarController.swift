import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let panelController: HistoryPanelController
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.panelController = HistoryPanelController(model: model)
        super.init()
        configureStatusItem()
        bindModel()
        updateIcon()
    }

    func togglePanel() {
        if panelController.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let button = statusItem.button else {
            panelController.show(relativeTo: nil)
            return
        }
        panelController.show(relativeTo: button.window)
    }

    func hidePanel() {
        panelController.hide()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Clippy"
    }

    private func bindModel() {
        model.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            model.requestTogglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(
            title: panelController.isVisible ? "Hide Clippy" : "Show Clipboard History",
            action: panelController.isVisible ? #selector(hidePanelFromMenu) : #selector(showHistoryFromMenu),
            keyEquivalent: ""
        ).targeting(self))

        menu.addItem(NSMenuItem(
            title: model.store.preferences.capturePaused ? "Resume Capture" : "Pause Capture",
            action: #selector(togglePauseFromMenu),
            keyEquivalent: ""
        ).targeting(self))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).targeting(self))

        menu.addItem(NSMenuItem(
            title: "Clear History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        ).targeting(self))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Clippy",
            action: #selector(quit),
            keyEquivalent: "q"
        ).targeting(self))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showHistoryFromMenu() {
        model.requestShowPanel()
    }

    @objc private func hidePanelFromMenu() {
        hidePanel()
    }

    @objc private func togglePauseFromMenu() {
        model.toggleCapturePaused()
    }

    @objc private func openSettings() {
        model.requestOpenSettings()
    }

    @objc private func clearHistory() {
        model.clearHistory()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateIcon() {
        guard let button = statusItem.button else {
            return
        }

        let symbolName: String
        switch model.menuBarState {
        case .active:
            symbolName = "paperclip"
        case .paused:
            symbolName = "pause.circle"
        case .setupNeeded:
            symbolName = "exclamationmark.triangle"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Clippy")
        image?.isTemplate = true
        button.image = image
    }
}

private extension NSMenuItem {
    func targeting(_ target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }
}
