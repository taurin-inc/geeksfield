import SwiftUI

struct ProjectRowView: View {
    let project: Project
    let imageCount: Int
    let latestImageCreatedAt: Date?
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .foregroundStyle(.tint)
                .font(.body)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)
                    .lineLimit(1)
                if let latestImageCreatedAt {
                    Text(appState.l10n.relativeDate(latestImageCreatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 6)

            if imageCount > 0 {
                Text("\(imageCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
