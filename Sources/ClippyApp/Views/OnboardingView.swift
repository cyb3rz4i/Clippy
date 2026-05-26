import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 18)

            Image(systemName: "paperclip")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 88, height: 88)

            VStack(spacing: 8) {
                Text("Clippy")
                    .font(.system(size: 34, weight: .bold))

                Text("Clipboard history for people who live on their keyboard.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                OnboardingPoint(systemImage: "lock.shield", title: "Local by default", detail: "History stays in this Mac app container.")
                OnboardingPoint(systemImage: "command", title: "Fast access", detail: "\(model.store.preferences.showHistoryShortcut.displayName) opens your history.")
                OnboardingPoint(systemImage: "hand.raised", title: "Permission-aware", detail: "Auto-paste is optional and copy-only mode always works.")
            }
            .frame(maxWidth: 420)

            HStack(spacing: 10) {
                Button {
                    model.completeOnboarding()
                } label: {
                    Label("Enable Clipboard History", systemImage: "checkmark.circle.fill")
                        .frame(width: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    model.requestOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer(minLength: 18)
        }
        .padding(34)
    }
}

private struct OnboardingPoint: View {
    var systemImage: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
