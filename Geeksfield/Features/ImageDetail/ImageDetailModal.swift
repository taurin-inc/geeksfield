import AppKit
import SwiftUI

/// Inline iteration workspace for one image lineage. The main surface is the
/// generation thread; metadata is available on demand through the inspector.
struct ImageThreadWorkspaceView: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @State private var inpaintOpen = false
    @State private var inspectorOpen = false
    @State private var copiedPrompt = false
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

                if inspectorOpen {
                    Divider().opacity(0.45)
                    ImageInspectorDrawer(asset: currentAsset)
                        .frame(width: 340)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .background(Color.black.opacity(0.18))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(12)
        .onTapGesture { /* absorb */ }
        .animation(.smooth(duration: 0.2), value: inspectorOpen)
    }

    private var topBar: some View {
        let l10n = appState.l10n
        return HStack(spacing: 10) {
            iconButton("xmark", help: l10n.close, action: dismiss)

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.iterationThread)
                    .font(.headline)
                Text(currentSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                appState.setBaseImage(currentAsset)
            } label: {
                Label(l10n.continueFromHere, systemImage: "target")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            .disabled(!currentAsset.hasFile)
            .opacity(currentAsset.hasFile ? 1 : 0.5)

            iconButton("wand.and.sparkles", help: l10n.edit) {
                if currentAsset.hasFile { inpaintOpen = true }
            }
            .disabled(!currentAsset.hasFile)
            iconButton(currentAsset.status == .picked ? "bookmark.fill" : "bookmark", help: l10n.pickedToggle) {
                togglePicked(currentAsset)
            }
            .disabled(!currentAsset.hasFile)
            iconButton("square.and.arrow.down", help: l10n.save) {
                appState.exportAsset(currentAsset)
            }
            .disabled(!currentAsset.hasFile)
            iconButton(inspectorOpen ? "info.circle.fill" : "info.circle", help: l10n.information) {
                inspectorOpen.toggle()
            }
            moreMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var currentSubtitle: String {
        var parts: [String] = []
        if let index = currentAsset.metadata.variantIndex {
            parts.append("#\(index)")
        }
        if currentAsset.status == .picked {
            parts.append(appState.l10n.picked)
        }
        parts.append(currentAsset.metadata.createdAt.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private var moreMenu: some View {
        let l10n = appState.l10n
        return Menu {
            Button(l10n.regenerate, systemImage: "arrow.triangle.2.circlepath") {
                appState.regenerate(currentAsset)
            }
            Button(l10n.useAsReference, systemImage: "photo.on.rectangle") {
                appState.useAsReference(currentAsset)
            }
            Button(copiedPrompt ? l10n.copied : l10n.copy, systemImage: "doc.on.doc") {
                copyPrompt(currentAsset)
            }
            Divider()
            Button(l10n.delete, systemImage: "trash", role: .destructive) {
                appState.deleteAsset(currentAsset)
                dismiss()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help(l10n.more)
    }

    private var threadScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(threadGroups) { group in
                        IterationThreadGroupSection(
                            group: group,
                            currentAssetID: currentAsset.id,
                            onSelect: { select($0) },
                            onContinue: {
                                appState.setBaseImage($0)
                            },
                            onEdit: {
                                select($0)
                                if $0.hasFile { inpaintOpen = true }
                            },
                            onPick: { togglePicked($0) }
                        )
                        .id(group.id)
                    }
                }
                .padding(.vertical, 18)
            }
            .onAppear {
                proxy.scrollTo(currentGroupID, anchor: .center)
            }
            .onChange(of: currentAsset.id) { _, _ in
                proxy.scrollTo(currentGroupID, anchor: .center)
            }
        }
    }

    private var threadRuns: [IterationRun] {
        appState.threadRuns(for: currentAsset)
    }

    private var threadGroups: [IterationThreadGroup] {
        IterationThreadGroup.group(threadRuns)
    }

    private var currentRunID: String {
        currentAsset.metadata.runID ?? currentAsset.id
    }

    private var currentGroupID: String {
        threadGroups.first { group in
            group.runs.contains { $0.id == currentRunID }
        }?.id ?? currentRunID
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

    private func copyPrompt(_ asset: ImageAsset) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(asset.metadata.prompt, forType: .string)
        copiedPrompt = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            copiedPrompt = false
        }
    }

    private func dismiss() {
        appState.presentedAsset = nil
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
                            showsPrompt: group.runs.count > 1,
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
                    .lineLimit(3)
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
                if let index = parent.metadata.variantIndex {
                    Text("#\(index)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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
        guard group.runs.count > 1 else {
            let prompt = group.runs.first?.prompt ?? ""
            return prompt.isEmpty ? appState.l10n.emptyPrompt : prompt
        }
        if let parent = parentAsset {
            let label = parent.metadata.variantIndex.map { "#\($0)" } ?? appState.l10n.parentImage
            return "\(appState.l10n.baseImage) \(label)"
        }
        return appState.l10n.baseImage
    }

    private var headerSubtitle: String {
        if group.runs.count > 1 {
            return "\(group.runs.count) \(appState.l10n.requests) · \(group.assets.count) \(appState.l10n.variants) · \(group.latestAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "\(group.assets.count) \(appState.l10n.variants) · \(group.latestAt.formatted(date: .abbreviated, time: .shortened))"
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
    let showsPrompt: Bool
    let onSelect: () -> Void
    let onContinue: () -> Void
    let onEdit: () -> Void
    let onPick: () -> Void

    @Environment(AppState.self) private var appState
    @State private var hovered = false
    @State private var imageAspect = CGFloat(1)

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            imageSurface
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)

            HStack(spacing: 8) {
                if let index = asset.metadata.variantIndex {
                    Text("#\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                }
                if isCurrent {
                    Text(appState.l10n.currentImage)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white))
                }
                if asset.status == .picked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Spacer(minLength: 0)
            }
            .frame(width: cardWidth)

            if showsPrompt {
                Text(asset.metadata.prompt.isEmpty ? appState.l10n.emptyPrompt : asset.metadata.prompt)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
    }

    private var imageSurface: some View {
        ZStack(alignment: .topTrailing) {
            assetImage
                .frame(width: cardWidth, height: cardHeight)

            if hovered || isCurrent {
                quickActions
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .opacity(isCurrent || hovered ? 1 : 0.46)
        .saturation(isCurrent || hovered ? 1 : 0.55)
        .scaleEffect(hovered ? 1.01 : 1)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.easeOut(duration: 0.18), value: isCurrent)
        .onHover { hovered = $0 }
        .task(id: asset.fileURL?.path ?? asset.thumbnailURL?.path ?? asset.id) {
            imageAspect = await ImageAspectReader.aspectRatio(for: asset)
        }
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
            icon("target", help: appState.l10n.continueFromHere, action: onContinue)
            icon("wand.and.sparkles", help: appState.l10n.edit, action: onEdit)
            icon(asset.status == .picked ? "bookmark.fill" : "bookmark", help: appState.l10n.pickedToggle, action: onPick)
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

    private var cardWidth: CGFloat {
        let base = CGFloat(250)
        let aspect = ImageAspectReader.clamped(imageAspect)
        if aspect >= 1 {
            return min(base * aspect, base * 1.55)
        }
        return base
    }

    private var cardHeight: CGFloat {
        let base = CGFloat(250)
        let aspect = ImageAspectReader.clamped(imageAspect)
        if aspect < 1 {
            return min(base / aspect, base * 1.55)
        }
        return base
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
                if let index = metadata.variantIndex {
                    rowDivider
                    infoRow(appState.l10n.variants, "#\(index)")
                }
                rowDivider
                infoRow(appState.l10n.infoCreated, metadata.createdAt.formatted(date: .abbreviated, time: .shortened))
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
