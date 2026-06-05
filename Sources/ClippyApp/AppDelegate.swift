import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let menuBarController = MenuBarController(model: model)
        self.menuBarController = menuBarController

        model.showPanel = { [weak menuBarController] in
            menuBarController?.showPanel()
        }
        model.hidePanel = { [weak menuBarController] in
            menuBarController?.hidePanel()
        }
        model.togglePanel = { [weak menuBarController] in
            menuBarController?.togglePanel()
        }

        model.start()

        if !model.store.preferences.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                menuBarController.showPanel()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.store.flushPendingHistorySaves()
    }
}
