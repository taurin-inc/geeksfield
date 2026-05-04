import SwiftUI

struct IterationBoardView: View {
    let groups: [IterationThreadGroup]
    let columns: Int
    var onSelect: (ImageAsset) -> Void = { _ in }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(groups) { group in
                    IterationGroupCard(group: group, onSelect: onSelect)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 10),
            count: max(3, min(columns, 6))
        )
    }
}

private struct IterationGroupCard: View {
    let group: IterationThreadGroup
    let onSelect: (ImageAsset) -> Void

    @Environment(AppState.self) private var appState

    private var latestAssets: [ImageAsset] {
        group.assets.sorted {
            if $0.metadata.createdAt == $1.metadata.createdAt { return $0.id > $1.id }
            return $0.metadata.createdAt > $1.metadata.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            previewArea

            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: openLatest)
    }

    private var previewArea: some View {
        GeometryReader { proxy in
            let side = max(1, proxy.size.width)
            previewCanvas(side: side)
                .frame(width: side, height: side)
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func previewCanvas(side: CGFloat) -> some View {
        if latestAssets.count <= 1 {
            previewCell(0)
                .frame(width: side, height: side)
        } else if latestAssets.count == 2 {
            let cellSide = max(1, (side - previewGap) / 2)
            HStack(spacing: previewGap) {
                ForEach(0..<2, id: \.self) { index in
                    previewCell(index)
                        .frame(width: cellSide, height: cellSide)
                }
            }
            .frame(width: side, height: side, alignment: .center)
        } else {
            let cellSide = max(1, (side - previewGap) / 2)
            VStack(spacing: previewGap) {
                HStack(spacing: previewGap) {
                    previewCell(0)
                        .frame(width: cellSide, height: cellSide)
                    previewCell(1)
                        .frame(width: cellSide, height: cellSide)
                }
                HStack(spacing: previewGap) {
                    previewCell(2)
                        .frame(width: cellSide, height: cellSide)
                    previewCell(3)
                        .frame(width: cellSide, height: cellSide)
                }
            }
            .frame(width: side, height: side, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func previewCell(_ index: Int) -> some View {
        if index < latestAssets.count {
            let asset = latestAssets[index]
            ZStack {
                BareAssetPreview(asset: asset)

                if index == 3, overflowCount > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.58))
                    Text("+\(overflowCount)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func openLatest() {
        if let asset = latestAssets.first {
            onSelect(asset)
        }
    }

    private var overflowCount: Int {
        max(0, latestAssets.count - 4)
    }

    private var previewGap: CGFloat { 3 }

    private var title: String {
        let rootPrompt = group.runs
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
            .first?
            .prompt ?? ""
        return rootPrompt.isEmpty ? appState.l10n.emptyPrompt : rootPrompt
    }
}

private struct BareAssetPreview: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if asset.status == .pending {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.16),
                            Color.white.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                if let url = asset.thumbnailURL ?? asset.fileURL {
                    LocalImage(url: url, contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else if asset.status == .pending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else if asset.status == .failed {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                if asset.status == .picked {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "bookmark.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.yellow)
                                .padding(5)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}
