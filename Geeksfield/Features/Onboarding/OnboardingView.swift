import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 28) {
                hero

                VStack(spacing: 12) {
                    CodexLoginRow()
                }

                footer
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 48)
            .padding(.vertical, 56)
            .frame(minWidth: 640, minHeight: 600)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("geeksfield")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(appState.l10n.onboardingSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack {
            Button(appState.l10n.skipForNow) { appState.markOnboardingComplete() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task {
                    await appState.modelRegistry.refresh()
                    appState.markOnboardingComplete()
                }
            } label: {
                Text(appState.l10n.getStarted)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(appState.connectedProviders.isEmpty)
        }
    }
}
