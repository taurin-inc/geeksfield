import SwiftUI

struct ModelSelector: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            if appState.modelRegistry.imageModels.isEmpty {
                Text(appState.l10n.noAvailableModels).foregroundStyle(.secondary)
            } else {
                ForEach(groupedByProvider, id: \.0) { provider, models in
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            Button {
                                appState.setImageModel(model)
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if appState.selectedImageModel?.id == model.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu").font(.caption)
                Text(appState.selectedImageModel?.displayName ?? appState.l10n.chooseModel)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var groupedByProvider: [(Provider, [ModelDescriptor])] {
        let grouped = Dictionary(grouping: appState.modelRegistry.imageModels) { $0.provider }
        return Provider.allCases.compactMap { p in
            guard let items = grouped[p], !items.isEmpty else { return nil }
            return (p, items)
        }
    }
}
