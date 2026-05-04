import AppKit
import SwiftUI

struct ImageDetailInfo: View {
    let asset: ImageAsset
    let onEdit: () -> Void
    let onRegenerate: () -> Void
    let onUseAsReference: () -> Void
    let onUseAsBase: () -> Void
    let onExport: () -> Void
    let onPick: () -> Void
    let onDelete: () -> Void

    @Environment(AppState.self) private var appState
    @State private var copied = false

    private var l10n: L10n { appState.l10n }

    private var metadata: ImageMetadata { asset.metadata }
    private var isPicked: Bool { asset.status == .picked }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    promptSection
                    relationshipSection
                    informationSection
                    if let reason = metadata.failureReason {
                        failureSection(reason: reason)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }

            Divider().opacity(0.4)

            actionsGrid
                .padding(18)
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - Prompt

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel(l10n.prompt.uppercased(), system: "text.alignleft")
                Spacer()
                Button(action: copyPrompt) {
                    Text(copied ? l10n.copied : l10n.copy)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay { Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                if !metadata.referenceIDs.isEmpty {
                    referenceChip
                }
                Text(metadata.prompt.isEmpty ? l10n.emptyPrompt : metadata.prompt)
                    .font(.callout)
                    .foregroundStyle(metadata.prompt.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
    }

    private var referenceChip: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.85, green: 1.0, blue: 0.30), Color(red: 0.55, green: 0.85, blue: 0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 36, height: 36)

            Text(l10n.referenceCount(metadata.referenceIDs.count))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Information

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l10n.information.uppercased(), system: "info.circle")

            VStack(spacing: 0) {
                infoRow(l10n.infoModel, metadata.modelID)
                rowDivider
                infoRow(l10n.infoProvider, metadata.provider.displayName)
                if let size = metadata.size {
                    rowDivider
                    infoRow(l10n.infoSize, size.description)
                }
                if let ratio = metadata.aspectRatio {
                    rowDivider
                    infoRow(l10n.infoAspect, ratio)
                }
                if let seed = metadata.seed {
                    rowDivider
                    infoRow(l10n.infoSeed, "\(seed)")
                }
                rowDivider
                infoRow(l10n.infoCreated, metadata.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().lineLimit(1).truncationMode(.middle)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private var actionsGrid: some View {
        HStack(spacing: 8) {
            saveButton
            bookmarkButton
            moreMenuButton
        }
    }

    private var saveButton: some View {
        Button(action: onExport) {
            Label(l10n.save, systemImage: "square.and.arrow.down")
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.85, green: 1.0, blue: 0.20))
                )
                .foregroundStyle(Color.black)
        }
        .buttonStyle(.plain)
        .disabled(!asset.hasFile)
        .opacity(asset.hasFile ? 1 : 0.5)
    }

    private var bookmarkButton: some View {
        Button(action: onPick) {
            Image(systemName: isPicked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isPicked ? Color.yellow : Color.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!asset.hasFile)
        .opacity(asset.hasFile ? 1 : 0.5)
    }

    private var moreMenuButton: some View {
        Menu {
            Button(l10n.regenerate, systemImage: "arrow.triangle.2.circlepath", action: onRegenerate)
            Button(l10n.edit, systemImage: "wand.and.stars", action: onEdit)
                .disabled(!asset.hasFile)
            Button(l10n.useAsBase, systemImage: "target", action: onUseAsBase)
                .disabled(!asset.hasFile)
            Button(l10n.useAsReference, systemImage: "photo.on.rectangle", action: onUseAsReference)
                .disabled(!asset.hasFile)
            Divider()
            Button(l10n.delete, systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }

    // MARK: - Relationships

    @ViewBuilder
    private var relationshipSection: some View {
        let parent = appState.parentAsset(for: asset)
        let runAssets = appState.runAssets(for: asset).filter { $0.id != asset.id }
        let children = appState.childAssets(of: asset)

        if parent != nil || !runAssets.isEmpty || !children.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(appState.l10n.iterationBoard.uppercased(), system: "point.3.connected.trianglepath.dotted")

                VStack(alignment: .leading, spacing: 12) {
                    if let parent {
                        relationRow(title: l10n.parentImage, assets: [parent])
                    }
                    if !runAssets.isEmpty {
                        relationRow(title: l10n.sameRun, assets: runAssets)
                    }
                    if !children.isEmpty {
                        relationRow(title: l10n.childImages, assets: children)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }

    private func relationRow(title: String, assets: [ImageAsset]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(assets) { related in
                        Button {
                            appState.presentedAsset = related
                        } label: {
                            relationThumb(related)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func relationThumb(_ asset: ImageAsset) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = asset.thumbnailURL ?? asset.fileURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.white.opacity(0.06)
                        }
                    }
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(asset.id == self.asset.id ? Color.accentColor : Color.white.opacity(0.10), lineWidth: 1)
            }

            if let index = asset.metadata.variantIndex {
                Text("#\(index)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(5)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, system: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
    }

    private func failureSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(l10n.failureSection.uppercased(), system: "exclamationmark.triangle.fill")
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.10))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
                }
        }
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(metadata.prompt, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            copied = false
        }
    }
}
