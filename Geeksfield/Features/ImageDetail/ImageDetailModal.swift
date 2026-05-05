import AppKit
import SwiftUI

/// Inline iteration workspace for one image lineage. The main surface is the
/// generation thread; metadata is available on demand through the inspector.
struct ImageThreadWorkspaceView: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @State private var inpaintOpen = false
    @State private var failedAsset: ImageAsset?

    private var currentAsset: ImageAsset {
        appState.presentedAsset ?? asset
    }

    var body: some View {
        workspace
        .background {
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
            Button("Export") { appState.exportAsset(currentAsset) }
                .keyboardShortcut("s", modifiers: .command)
                .opacity(0)
                .disabled(!currentAsset.hasFile)
        }
        .sheet(isPresented: $inpaintOpen) {
            InpaintSheet(asset: currentAsset)
                .environment(appState)
        }
        .failedImageAlert(asset: $failedAsset, dismissPresentedAsset: true)
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.45)
            HStack(spacing: 0) {
                threadScroll
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.45)

                SelectedImageSidebar(
                    asset: currentAsset,
                    onContinue: {
                        appState.setBaseImage(currentAsset)
                    },
                    onEdit: {
                        if currentAsset.hasFile { inpaintOpen = true }
                    },
                    onPick: {
                        togglePicked(currentAsset)
                    },
                    onExport: {
                        appState.exportAsset(currentAsset)
                    },
                    onRegenerate: {
                        appState.regenerate(currentAsset)
                    },
                    onUseAsReference: {
                        appState.useAsReference(currentAsset)
                    },
                    onDelete: {
                        appState.deleteAsset(currentAsset)
                        dismiss()
                    }
                )
                .frame(width: 310)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .background(Color.black.opacity(0.18))
        .onTapGesture { /* absorb */ }
    }

    private var topBar: some View {
        let l10n = appState.l10n
        return HStack(spacing: 10) {
            iconButton("xmark", help: l10n.close, action: dismiss)

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.workTree)
                    .font(.headline)
                Text(treeSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var treeSubtitle: String {
        "\(threadRuns.count) \(appState.l10n.requests) · \(threadRuns.reduce(0) { $0 + $1.assets.count }) \(appState.l10n.variants)"
    }

    private var threadScroll: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(threadRunsNewestFirst.enumerated()), id: \.element.id) { index, run in
                            ImageThreadRunSection(
                                run: run,
                                requestNumber: threadRuns.count - index,
                                currentAssetID: currentAsset.id,
                                onSelect: { select($0) },
                                onContinue: { appState.setBaseImage($0) },
                                onEdit: { asset in
                                    select(asset)
                                    if asset.hasFile { inpaintOpen = true }
                                },
                                onPick: { togglePicked($0) }
                            )
                            .id(run.id)
                        }
                    }
                    .frame(width: max(geometry.size.width, 250), alignment: .topLeading)
                }
                .onAppear {
                    proxy.scrollTo(currentAsset.id, anchor: .center)
                }
                .onChange(of: currentAsset.id) { _, _ in
                    proxy.scrollTo(currentAsset.id, anchor: .center)
                }
            }
        }
    }

    private var threadRuns: [IterationRun] {
        appState.threadRuns(for: asset)
    }

    private var threadRunsNewestFirst: [IterationRun] {
        threadRuns.sorted {
            if $0.latestAt == $1.latestAt { return $0.id > $1.id }
            return $0.latestAt > $1.latestAt
        }
    }

    private func iconButton(_ system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func select(_ asset: ImageAsset) {
        guard asset.status != .failed else {
            failedAsset = asset
            return
        }
        appState.presentedAsset = asset
    }

    private func togglePicked(_ asset: ImageAsset) {
        appState.setStatus(asset, to: asset.status == .picked ? .draft : .picked)
        if let updated = appState.asset(withID: asset.id, in: asset.metadata.projectID) {
            appState.presentedAsset = updated
        }
    }

    private func dismiss() {
        appState.presentedAsset = nil
    }
}

private struct ImageThreadRunSection: View {
    let run: IterationRun
    let requestNumber: Int
    let currentAssetID: String
    let onSelect: (ImageAsset) -> Void
    let onContinue: (ImageAsset) -> Void
    let onEdit: (ImageAsset) -> Void
    let onPick: (ImageAsset) -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            runHeader

            AdaptiveImageGridLayout(rowHeight: 250, spacing: 6) {
                ForEach(run.assets) { asset in
                    AdaptiveImageGridItem(asset: asset) {
                        IterationThreadAssetCard(
                            asset: asset,
                            isCurrent: asset.id == currentAssetID,
                            onSelect: { onSelect(asset) },
                            onContinue: { onContinue(asset) },
                            onEdit: { onEdit(asset) },
                            onPick: { onPick(asset) }
                        )
                        .id(asset.id)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private var runHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(requestNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 5) {
                Text(run.prompt.isEmpty ? appState.l10n.emptyPrompt : run.prompt)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !sourceItems.isEmpty {
                sourceStrip
            }
        }
        .padding(.horizontal, 20)
    }

    private var sourceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sourceItems) { item in
                    RequestSourceThumbnail(item: item) {
                        if let assetID = item.assetID,
                           let asset = appState.asset(withID: assetID, in: run.projectID) {
                            onSelect(asset)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: CGFloat(sourceItems.count) * 44 + CGFloat(max(0, sourceItems.count - 1)) * 8, alignment: .trailing)
    }

    private var sourceItems: [RequestSourceItem] {
        var items: [RequestSourceItem] = []
        if let parentID = run.parentImageID,
           let parent = appState.asset(withID: parentID, in: run.projectID),
           let url = parent.thumbnailURL ?? parent.fileURL {
            items.append(RequestSourceItem(
                id: "parent:\(parentID)",
                title: appState.l10n.parentImage,
                url: url,
                assetID: parentID
            ))
        }

        let parentID = run.parentImageID
        for refID in run.referenceIDs where refID != parentID {
            if let url = appState.referenceThumbnailURL(for: refID) {
                items.append(RequestSourceItem(
                    id: "reference:\(refID)",
                    title: appState.l10n.reference,
                    url: url,
                    assetID: refID.hasPrefix("ref_") ? nil : refID
                ))
            }
        }
        return items
    }

    private var headerSubtitle: String {
        "\(run.assets.count) \(appState.l10n.variants) · \(appState.l10n.dateTime(run.latestAt))"
    }
}

private struct RequestSourceItem: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let assetID: String?
}

private struct RequestSourceThumbnail: View {
    let item: RequestSourceItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                LocalImage(url: item.url, contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipped()
            }
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(item.title)
    }
}

private struct SelectedImageSidebar: View {
    let asset: ImageAsset
    let onContinue: () -> Void
    let onEdit: () -> Void
    let onPick: () -> Void
    let onExport: () -> Void
    let onRegenerate: () -> Void
    let onUseAsReference: () -> Void
    let onDelete: () -> Void

    @Environment(AppState.self) private var appState
    @State private var copiedPrompt = false

    private var metadata: ImageMetadata { asset.metadata }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    promptBlock
                    informationBlock
                    if let reason = metadata.failureReason {
                        failureBlock(reason)
                    }
                }
                .padding(18)
            }

            Divider().opacity(0.4)

            actions
                .padding(18)
        }
        .background(Color.black.opacity(0.20))
    }

    private var preview: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                if let url = asset.thumbnailURL ?? asset.fileURL {
                    LocalImage(url: url, contentMode: .fit)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else if asset.status == .pending {
                    ProgressView().controlSize(.small)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else if asset.status == .failed {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                if asset.status == .picked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
    }

    private var promptBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel(appState.l10n.prompt.uppercased(), system: "text.alignleft")
                Spacer()
                Button(action: copyPrompt) {
                    Text(copiedPrompt ? appState.l10n.copied : appState.l10n.copy)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            Text(metadata.prompt.isEmpty ? appState.l10n.emptyPrompt : metadata.prompt)
                .font(.callout)
                .foregroundStyle(metadata.prompt.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        }
    }

    private var informationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(appState.l10n.information.uppercased(), system: "info.circle")
            VStack(spacing: 0) {
                infoRow(appState.l10n.infoModel, metadata.modelID)
                rowDivider
                infoRow(appState.l10n.infoProvider, metadata.provider.displayName)
                if let size = metadata.size {
                    rowDivider
                    infoRow(appState.l10n.infoSize, size.description)
                }
                if let ratio = metadata.aspectRatio {
                    rowDivider
                    infoRow(appState.l10n.infoAspect, ratio)
                }
                if let seed = metadata.seed {
                    rowDivider
                    infoRow(appState.l10n.infoSeed, "\(seed)")
                }
                rowDivider
                infoRow(appState.l10n.infoCreated, appState.l10n.dateTime(metadata.createdAt))
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("target", title: appState.l10n.continueFromHere, action: onContinue)
                actionButton("wand.and.sparkles", title: appState.l10n.edit, action: onEdit)
            }
            HStack(spacing: 8) {
                actionButton(asset.status == .picked ? "bookmark.fill" : "bookmark", title: appState.l10n.pickedToggle, action: onPick)
                actionButton("square.and.arrow.down", title: appState.l10n.save, action: onExport)
                moreMenu
            }
        }
    }

    private func actionButton(_ system: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!asset.hasFile)
        .opacity(asset.hasFile ? 1 : 0.5)
    }

    private var moreMenu: some View {
        Menu {
            Button(appState.l10n.regenerate, systemImage: "arrow.triangle.2.circlepath", action: onRegenerate)
            Button(appState.l10n.useAsReference, systemImage: "photo.on.rectangle", action: onUseAsReference)
                .disabled(!asset.hasFile)
            Divider()
            Button(appState.l10n.delete, systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 40, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help(appState.l10n.more)
    }

    private func failureBlock(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(appState.l10n.failureSection.uppercased(), system: "exclamationmark.triangle.fill")
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.10)))
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

    private func sectionLabel(_ title: String, system: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(metadata.prompt, forType: .string)
        copiedPrompt = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            copiedPrompt = false
        }
    }
}

private struct IterationThreadGroupSection: View {
    let group: IterationThreadGroup
    let currentAssetID: String
    let onSelect: (ImageAsset) -> Void
    let onContinue: (ImageAsset) -> Void
    let onEdit: (ImageAsset) -> Void
    let onPick: (ImageAsset) -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            runHeader

            if let parent = parentAsset {
                parentLine(parent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(group.assets) { asset in
                        IterationThreadAssetCard(
                            asset: asset,
                            isCurrent: asset.id == currentAssetID,
                            onSelect: { onSelect(asset) },
                            onContinue: { onContinue(asset) },
                            onEdit: { onEdit(asset) },
                            onPick: { onPick(asset) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private var runHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Label(operationLabel, systemImage: operationIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 5) {
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private func parentLine(_ parent: ImageAsset) -> some View {
        Button {
            onSelect(parent)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(appState.l10n.parentImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(parent.metadata.prompt.isEmpty ? appState.l10n.emptyPrompt : parent.metadata.prompt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var parentAsset: ImageAsset? {
        guard let parentID = group.parentImageID else { return nil }
        return appState.asset(withID: parentID, in: group.projectID)
    }

    private var headerTitle: String {
        let prompt = group.runs.first?.prompt ?? parentAsset?.metadata.prompt ?? ""
        return prompt.isEmpty ? appState.l10n.emptyPrompt : prompt
    }

    private var headerSubtitle: String {
        if group.runs.count > 1 {
            return "\(group.runs.count) \(appState.l10n.requests) · \(group.assets.count) \(appState.l10n.variants) · \(appState.l10n.dateTime(group.latestAt))"
        }
        return "\(group.assets.count) \(appState.l10n.variants) · \(appState.l10n.dateTime(group.latestAt))"
    }

    private var operationLabel: String {
        switch group.operation {
        case .generate: return appState.l10n.generate
        case .reference: return appState.l10n.reference
        case .inpaint: return appState.l10n.edit
        }
    }

    private var operationIcon: String {
        switch group.operation {
        case .generate: return "sparkles"
        case .reference: return "photo.on.rectangle"
        case .inpaint: return "wand.and.sparkles"
        }
    }
}

private struct IterationThreadAssetCard: View {
    let asset: ImageAsset
    let isCurrent: Bool
    let onSelect: () -> Void
    let onContinue: () -> Void
    let onEdit: () -> Void
    let onPick: () -> Void

    @Environment(AppState.self) private var appState
    @State private var hovered = false

    var body: some View {
        imageSurface
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }

    private var imageSurface: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                assetImage
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                quickActions
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(1)
        .saturation(1)
        .animation(.easeOut(duration: 0.18), value: isCurrent)
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var assetImage: some View {
        if let url = asset.fileURL {
            LocalImage(url: url, contentMode: .fit)
        } else if asset.status == .pending {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                    .frame(width: 18, height: 18)
                Text(appState.l10n.generating)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if asset.status == .failed {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(appState.l10n.failed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.tertiary)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 6) {
            if asset.hasFile, hovered || isCurrent {
                icon("target", help: appState.l10n.continueFromHere, action: onContinue)
                    .transition(.opacity)
                icon("wand.and.sparkles", help: appState.l10n.edit, action: onEdit)
                    .transition(.opacity)
            }
            if asset.hasFile, hovered || asset.status == .picked {
                icon(asset.status == .picked ? "bookmark.fill" : "bookmark", help: appState.l10n.pickedToggle, action: onPick)
            }
        }
    }

    private func icon(_ system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!asset.hasFile)
        .opacity(asset.hasFile ? 1 : 0.45)
        .help(help)
    }

}

private struct ImageInspectorDrawer: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState

    private var metadata: ImageMetadata { asset.metadata }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                promptBlock
                informationBlock
                if let reason = metadata.failureReason {
                    failureBlock(reason)
                }
            }
            .padding(18)
        }
        .background(Color.black.opacity(0.20))
    }

    private var promptBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(appState.l10n.prompt.uppercased(), system: "text.alignleft")
            Text(metadata.prompt.isEmpty ? appState.l10n.emptyPrompt : metadata.prompt)
                .font(.callout)
                .foregroundStyle(metadata.prompt.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        }
    }

    private var informationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(appState.l10n.information.uppercased(), system: "info.circle")
            VStack(spacing: 0) {
                infoRow(appState.l10n.infoModel, metadata.modelID)
                rowDivider
                infoRow(appState.l10n.infoProvider, metadata.provider.displayName)
                if let size = metadata.size {
                    rowDivider
                    infoRow(appState.l10n.infoSize, size.description)
                }
                if let ratio = metadata.aspectRatio {
                    rowDivider
                    infoRow(appState.l10n.infoAspect, ratio)
                }
                if let seed = metadata.seed {
                    rowDivider
                    infoRow(appState.l10n.infoSeed, "\(seed)")
                }
                rowDivider
                infoRow(appState.l10n.infoCreated, appState.l10n.dateTime(metadata.createdAt))
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        }
    }

    private func failureBlock(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(appState.l10n.failureSection.uppercased(), system: "exclamationmark.triangle.fill")
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.10)))
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

    private func sectionLabel(_ title: String, system: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
