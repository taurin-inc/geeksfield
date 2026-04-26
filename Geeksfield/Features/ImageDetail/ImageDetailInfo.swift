import SwiftUI

struct ImageDetailInfo: View {
    let metadata: ImageMetadata

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                modelSection
                Divider()
                paramsSection
                Divider()
                promptSection
                if let reason = metadata.failureReason {
                    Divider()
                    failureSection(reason: reason)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.regularMaterial)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metadata.provider.displayName.uppercased())
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            Text(metadata.modelID)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Text(metadata.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parameters")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                if let size = metadata.size {
                    paramRow("Size", size.description)
                }
                if let ratio = metadata.aspectRatio {
                    paramRow("Aspect", ratio)
                }
                if let seed = metadata.seed {
                    paramRow("Seed", "\(seed)")
                }
                if !metadata.referenceIDs.isEmpty {
                    paramRow("References", "\(metadata.referenceIDs.count)")
                }
            }
        }
    }

    private func paramRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(metadata.prompt)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func failureSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("실패 사유", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text(reason)
                .font(.callout)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
        }
    }
}
