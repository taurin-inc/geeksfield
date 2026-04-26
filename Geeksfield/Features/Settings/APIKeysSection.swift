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

/// Single-key entry row. The text field is always empty so that typing never
/// concatenates with the previously-saved key. The currently-stored key is
/// confirmed visually via its last 4 characters.
struct ProviderKeyRow: View {
    let provider: Provider

    @Environment(AppState.self) private var appState
    @State private var field = ProviderKeyFieldState()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            inputRow
            statusLine
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 18, alignment: .leading)
            Text(provider.displayName)
                .font(.headline)
            Spacer()
            Link(destination: provider.apiKeyURL) {
                Label(appState.l10n.getKey, systemImage: "arrow.up.forward.square")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.link)
        }
    }

    private var inputRow: some View {
        let l10n = appState.l10n
        return HStack(alignment: .center, spacing: 8) {
            SecureField(savedKeyExists ? l10n.enterToReplace : "API Key", text: $field.draft)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await saveAndValidate() }
            } label: {
                if field.validation == .validating {
                    ProgressView().controlSize(.small)
                } else {
                    Text(savedKeyExists ? l10n.replaceAndVerify : l10n.saveAndVerify)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(field.draft.trimmingCharacters(in: .whitespaces).isEmpty || field.validation == .validating)
            .frame(minWidth: 110)

            if savedKeyExists {
                Button(role: .destructive) {
                    try? appState.keychain.deleteAPIKey(for: provider)
                    field.draft = ""
                    field.validation = .idle
                    Task { await appState.modelRegistry.refresh() }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .help(l10n.deleteSavedKey)
            }
        }
    }

    private var iconName: String {
        switch provider {
        case .openai: return "circle.hexagongrid"
        case .gemini: return "diamond"
        }
    }

    private var savedKeyExists: Bool {
        appState.keychain.apiKey(for: provider) != nil
    }

    private var savedKeyHint: String? {
        guard let key = appState.keychain.apiKey(for: provider), key.count >= 4 else { return nil }
        return "····" + String(key.suffix(4))
    }

    @ViewBuilder
    private var statusLine: some View {
        let l10n = appState.l10n
        HStack(spacing: 6) {
            switch field.validation {
            case .idle:
                if let hint = savedKeyHint {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(l10n.saved).foregroundStyle(.secondary)
                    Text(hint).monospaced().foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "circle.dashed").foregroundStyle(.tertiary)
                    Text(l10n.enterAndSaveKey).foregroundStyle(.secondary)
                }
            case .validating:
                ProgressView().controlSize(.small)
                Text(l10n.verifying).foregroundStyle(.secondary)
            case .valid(let modelCount):
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text(l10n.validKeyModelCount(modelCount)).foregroundStyle(.secondary)
                if let hint = savedKeyHint {
                    Text(hint).monospaced().foregroundStyle(.tertiary)
                }
            case .invalid(let msg):
                Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
                Text(msg).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveAndValidate() async {
        field.validation = .validating
        let raw = field.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let lister: any ModelLister = (provider == .openai) ? OpenAIModelLister() : GeminiModelLister()
        do {
            let ids = try await lister.listAvailableModelIDs(apiKey: raw)
            try appState.keychain.setAPIKey(raw, for: provider)
            await appState.modelRegistry.refresh()
            field.validation = .valid(modelCount: ids.count)
            field.draft = ""
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? appState.l10n.verificationFailed
            field.validation = .invalid(msg)
        }
    }
}
