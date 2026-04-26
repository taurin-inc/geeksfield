import SwiftUI

struct ChatModelSelector: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            if appState.modelRegistry.chatModels.isEmpty {
                Text(appState.l10n.noAvailableModels).foregroundStyle(.secondary)
            } else {
                ForEach(grouped, id: \.0) { provider, models in
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            Button {
                                appState.setChatModel(model)
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if appState.selectedChatModel?.id == model.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.text.bubble.right").font(.caption)
                Text(appState.selectedChatModel?.displayName ?? appState.l10n.chatModel)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var grouped: [(Provider, [ModelDescriptor])] {
        let dict = Dictionary(grouping: appState.modelRegistry.chatModels) { $0.provider }
        return Provider.allCases.compactMap { p in
            guard let items = dict[p], !items.isEmpty else { return nil }
            return (p, items)
        }
    }
}
