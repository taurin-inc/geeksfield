import SwiftUI

enum ProviderKeyValidation: Equatable, Sendable {
    case idle
    case validating
    case valid(modelCount: Int)
    case invalid(String)
}

@Observable
@MainActor
final class ProviderKeyFieldState {
    var draft: String = ""
    var validation: ProviderKeyValidation = .idle
}

struct CodexLoginRow: View {
    @Environment(AppState.self) private var appState
    @State private var validation: ProviderKeyValidation = .idle

    private let authStore = CodexAuthStore()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    SettingsIconTile(systemName: "terminal")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(Provider.codex.displayName)
                            .font(.headline)
                        Text(appState.l10n.codexUsesSubscription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)
                    statusBadge
                }

                if !isConnected {
                    if let message = statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(statusMessageColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        Link(destination: Provider.codex.apiKeyURL) {
                            Label("Codex CLI", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(.bordered)

                        Spacer(minLength: 0)

                        Button {
                            Task { await checkLogin() }
                        } label: {
                            HStack(spacing: 6) {
                                if validation == .validating {
                                    ProgressView().controlSize(.small)
                                }
                                Text(appState.l10n.checkCodexLogin)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(validation == .validating)
                    }
                }
            }
        }
        .task {
            if authStore.isSignedIn() {
                validation = .valid(modelCount: 1)
            }
        }
    }

    private var isConnected: Bool {
        switch validation {
        case .idle:
            return authStore.isSignedIn()
        case .valid:
            return true
        case .validating, .invalid:
            return false
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: statusIcon)
                .font(.caption.weight(.bold))
            Text(statusTitle)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(statusColor.opacity(0.12)))
    }

    private var statusIcon: String {
        switch validation {
        case .idle:
            return authStore.isSignedIn() ? "checkmark.circle.fill" : "circle.dashed"
        case .validating:
            return "arrow.triangle.2.circlepath"
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "exclamationmark.circle.fill"
        }
    }

    private var statusTitle: String {
        switch validation {
        case .idle:
            return authStore.isSignedIn() ? appState.l10n.connected : appState.l10n.notConnected
        case .validating:
            return appState.l10n.verifying
        case .valid:
            return appState.l10n.connected
        case .invalid:
            return appState.l10n.error
        }
    }

    private var statusColor: Color {
        switch validation {
        case .idle:
            return authStore.isSignedIn() ? .green : .secondary
        case .validating:
            return .blue
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }

    private var statusMessage: String? {
        switch validation {
        case .idle:
            return authStore.isSignedIn() ? appState.l10n.codexLoginDetected : appState.l10n.codexLoginMissing
        case .validating:
            return nil
        case .valid:
            return appState.l10n.codexLoginDetected
        case .invalid(let msg):
            return msg
        }
    }

    private var statusMessageColor: Color {
        if case .invalid = validation {
            return .red.opacity(0.9)
        }
        return .secondary
    }

    private func checkLogin() async {
        validation = .validating
        do {
            _ = try authStore.load()
            await appState.modelRegistry.refresh()
            validation = .valid(modelCount: 1)
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? appState.l10n.codexLoginMissing
            validation = .invalid(msg)
        }
    }
}
