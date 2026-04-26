import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case apiKeys, models, advanced
    var id: Self { self }
    var title: String {
        switch self {
        case .apiKeys: return "API Keys"
        case .models: return "Models"
        case .advanced: return "Advanced"
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var section: SettingsSection = .apiKeys

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
                Text(s.title).tag(s)
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
            Button("완료") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
