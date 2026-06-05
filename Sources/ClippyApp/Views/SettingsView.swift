import ClippyCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            general
                .tabItem {
                    Label("General", systemImage: "switch.2")
                }

            shortcuts
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }

            privacy
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }

            storage
                .tabItem {
                    Label("Storage", systemImage: "internaldrive")
                }
        }
        .padding(20)
    }

    private var general: some View {
        Form {
            Toggle("Capture clipboard history", isOn: Binding(
                get: { model.store.preferences.captureEnabled },
                set: { model.setCaptureEnabled($0) }
            ))

            Toggle("Pause capture", isOn: Binding(
                get: { model.store.preferences.capturePaused },
                set: { model.setCapturePaused($0) }
            ))

            Toggle("Launch at login", isOn: Binding(
                get: { model.store.preferences.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Toggle("Paste automatically when Accessibility allows it", isOn: Binding(
                get: { model.store.preferences.autoPasteWhenAllowed },
                set: { model.setAutoPasteWhenAllowed($0) }
            ))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("History limit")
                    Spacer()
                    Text("\(model.store.preferences.historyLimit)")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.store.preferences.historyLimit) },
                        set: { model.setHistoryLimit($0) }
                    ),
                    in: 10...1_000,
                    step: 10
                )
            }
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Click a shortcut, then press a new key combination. Use Command, Control, or Option with a key.")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            ShortcutRow(
                title: "Show clipboard history",
                shortcut: model.store.preferences.showHistoryShortcut,
                onChange: model.setShowHistoryShortcut
            )

            ShortcutRow(
                title: "Paste latest item",
                shortcut: model.store.preferences.pasteLatestShortcut,
                onChange: model.setPasteLatestShortcut
            )

            ShortcutRow(
                title: "Pause or resume capture",
                shortcut: model.store.preferences.pauseCaptureShortcut,
                onChange: model.setPauseCaptureShortcut
            )

            Divider()

            HStack {
                if let toast = model.toastMessage {
                    Text(toast)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.resetShortcutsToDefaults()
                } label: {
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Clipboard access") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Clippy stores clipboard history locally on this Mac and does not use accounts, sync, analytics, or network access.")
                        .foregroundStyle(.secondary)

                    Text("Selecting an item writes it back to the pasteboard. With Accessibility permission, Clippy can paste it into the previous app automatically.")
                        .foregroundStyle(.secondary)

                    Button {
                        model.openAccessibilitySettings()
                    } label: {
                        Label("Accessibility Settings", systemImage: "figure.wave")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!model.store.preferences.autoPasteWhenAllowed)
                    .help("Open macOS Accessibility privacy settings")
                }
                .padding(.vertical, 4)
            }

            GroupBox("Auto-paste") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Paste automatically when allowed", isOn: Binding(
                        get: { model.store.preferences.autoPasteWhenAllowed },
                        set: { model.setAutoPasteWhenAllowed($0) }
                    ))

                    Text("Auto-paste falls back to copy-only when Accessibility access is not granted.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            GroupBox("Excluded apps") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button {
                            model.chooseAppForExclusion()
                        } label: {
                            Label("Add App…", systemImage: "plus")
                        }

                        Button {
                            model.addFrontmostAppToExclusions()
                        } label: {
                            Label("Exclude Frontmost", systemImage: "scope")
                        }

                        Spacer()
                    }

                    if model.store.preferences.excludedBundleIDs.isEmpty {
                        Text("No excluded apps")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.store.preferences.excludedBundleIDs.sorted(), id: \.self) { bundleID in
                            HStack {
                                Text(bundleID)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button {
                                    model.removeExcludedBundleID(bundleID)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Local storage") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.store.storageDirectory.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button(role: .destructive) {
                            model.clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }

                        Button {
                            model.clearUnpinnedHistory()
                        } label: {
                            Label("Clear Unpinned", systemImage: "pin")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
    }
}

private struct ShortcutRow: View {
    var title: String
    var shortcut: GlobalShortcut
    var onChange: (GlobalShortcut) -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            ShortcutRecorderView(shortcut: shortcut, onChange: onChange)
                .frame(width: 210, height: 34)
        }
    }
}
