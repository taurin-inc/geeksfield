import SwiftUI

struct ModelCatalogSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if appState.modelRegistry.imageModels.isEmpty
                && appState.modelRegistry.chatModels.isEmpty {
                ContentUnavailableView(
                    "아직 모델이 없습니다",
                    systemImage: "questionmark.square.dashed",
                    description: Text("API 키를 먼저 연결하세요.")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                modelGroup(title: "Image", models: appState.modelRegistry.imageModels)
                modelGroup(title: "Chat", models: appState.modelRegistry.chatModels)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Discovered models")
                .font(.headline)
            Spacer()
            Button {
                Task { await appState.modelRegistry.refresh() }
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
        }
    }

    private func modelGroup(title: String, models: [ModelDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            VStack(spacing: 0) {
                ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                    if index > 0 { Divider() }
                    modelRow(model)
                }
                if models.isEmpty {
                    Text("없음")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
    }

    private func modelRow(_ model: ModelDescriptor) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(model.displayName)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Text(model.provider.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
