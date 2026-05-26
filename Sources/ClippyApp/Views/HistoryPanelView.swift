import ClippyCore
import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            if model.panelMode == .settings {
                embeddedSettings
            } else if !model.store.preferences.hasCompletedOnboarding {
                OnboardingView(model: model)
            } else {
                historyContent
            }
        }
        .onAppear {
            if model.panelMode == .history {
                searchFocused = true
                model.selectedIndex = 0
            }
        }
        .onChange(of: model.query) { _, _ in
            model.selectedIndex = 0
        }
        .onMoveCommand { direction in
            guard model.panelMode == .history else {
                return
            }
            switch direction {
            case .down:
                model.selectNext()
            case .up:
                model.selectPrevious()
            default:
                break
            }
        }
        .onExitCommand {
            if model.panelMode == .settings {
                model.requestShowHistory()
            } else {
                model.hidePanel?()
            }
        }
    }

    private var embeddedSettings: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    model.requestShowHistory()
                } label: {
                    Label("History", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("Back to clipboard history")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Tune Clippy without leaving the app.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let toast = model.toastMessage {
                    Text(toast)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.regularMaterial)

            Divider()

            SettingsView(model: model)
        }
    }

    private var historyContent: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if model.filteredItems.isEmpty {
                EmptyHistoryView(query: model.query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(model.filteredItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemRow(
                                    item: item,
                                    index: index,
                                    isSelected: index == model.selectedIndex,
                                    onChoose: { model.choose(item) },
                                    onPin: { model.togglePinned(item) },
                                    onDelete: { model.delete(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: model.selectedIndex) { _, newValue in
                        let items = model.filteredItems
                        guard items.indices.contains(newValue) else {
                            return
                        }
                        withAnimation(.snappy(duration: 0.16)) {
                            proxy.scrollTo(items[newValue].id, anchor: .center)
                        }
                    }
                }
            }

            footer
        }
        .overlay(alignment: .bottom) {
            QuickSelectButtons(model: model)
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search clipboard history", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .focused($searchFocused)
                    .onSubmit {
                        model.chooseSelectedItem()
                    }

                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                StatusPill(
                    title: model.store.preferences.capturePaused ? "Paused" : "Capturing",
                    systemImage: model.store.preferences.capturePaused ? "pause.circle.fill" : "record.circle",
                    tint: .primary
                )

                if !model.isAccessibilityTrusted && model.store.preferences.autoPasteWhenAllowed {
                    StatusPill(
                        title: "Copy-only until Accessibility is enabled",
                        systemImage: "hand.raised.fill",
                        tint: .primary
                    )
                }

                Spacer()

                Button {
                    model.toggleCapturePaused()
                } label: {
                    Image(systemName: model.store.preferences.capturePaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                .help(model.store.preferences.capturePaused ? "Resume capture" : "Pause capture")

                Button {
                    model.requestOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(model.filteredItems.count) items")
                .foregroundStyle(.secondary)

            if let toast = model.toastMessage {
                Text(toast)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Enter to paste • Esc to close")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

private struct QuickSelectButtons: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ForEach(1...9, id: \.self) { number in
            Button("") {
                model.selectItem(at: number - 1)
            }
            .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: [])
        }
    }
}

private struct StatusPill: View {
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.075), in: Capsule())
    }
}

private struct EmptyHistoryView: View {
    var query: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: query.isEmpty ? "paperclip" : "magnifyingglass.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text(query.isEmpty ? "Your clipboard history will appear here" : "No matching clips")
                .font(.system(size: 18, weight: .semibold))

            Text(query.isEmpty ? "Copy text, links, or images from any app." : "Try a shorter search.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(40)
    }
}
