import SwiftUI

struct AdvancedSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var registry = appState.modelRegistry
        VStack(alignment: .leading, spacing: 16) {
            Text("Model discovery")
                .font(.headline)

            VStack(spacing: 0) {
                Toggle("알 수 없는 모델도 표시", isOn: $registry.showUnknownModels)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                if let when = registry.lastRefreshedAt {
                    Divider()
                    HStack {
                        Text("마지막 새로고침")
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
