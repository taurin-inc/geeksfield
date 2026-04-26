import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, apiKeys, models, advanced
    var id: Self { self }

    func title(_ l10n: L10n) -> String {
        switch self {
        case .general: return l10n.settingsGeneral
        case .apiKeys: return l10n.settingsApiKeys
        case .models: return l10n.settingsModels
        case .advanced: return l10n.settingsAdvanced
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var section: SettingsSection = .general

    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 580, height: 560)
        .controlSize(.regular)
        .buttonBorderShape(.automatic)
        .background {
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        }
    }

    private var sectionPicker: some View {
        Picker("", selection: $section) {
            ForEach(SettingsSection.allCases) { s in
                Text(s.title(appState.l10n)).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            Group {
                switch section {
                case .general:
                    GeneralSection()
                case .apiKeys:
                    VStack(alignment: .leading, spacing: 14) {
                        ProviderKeyRow(provider: .openai)
                        ProviderKeyRow(provider: .gemini)
                    }
                case .models:
                    ModelCatalogSection()
                case .advanced:
                    AdvancedSection()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(appState.l10n.done) { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
