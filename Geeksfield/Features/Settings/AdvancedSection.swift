import SwiftUI

struct AdvancedSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var registry = appState.modelRegistry
        let l10n = appState.l10n
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.modelDiscovery)
                .font(.headline)

            VStack(spacing: 0) {
                Toggle(l10n.showUnknownModels, isOn: $registry.showUnknownModels)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                if let when = registry.lastRefreshedAt {
                    Divider()
                    HStack {
                        Text(l10n.lastRefreshed)
                        Spacer()
                        Text(when.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
    }
}
