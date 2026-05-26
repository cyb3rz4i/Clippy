import SwiftUI

@main
struct ClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(model: appDelegate.model)
                .frame(width: 680, height: 500)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.model.requestOpenSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Button("Show Clipboard History") {
                    appDelegate.model.requestShowPanel()
                }
                .keyboardShortcut("v", modifiers: [.control, .option])

                Button("Paste Latest Item") {
                    appDelegate.model.pasteLatest()
                }
                .keyboardShortcut("v", modifiers: [.shift, .control, .option])
            }
        }
    }
}
