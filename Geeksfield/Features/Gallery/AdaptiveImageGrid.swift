import SwiftUI

struct ImageAspectLayoutKey: LayoutValueKey {
    static let defaultValue = CGFloat(1)
}

struct AdaptiveImageGridLayout: Layout {
    let rowHeight: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(proposal.width ?? 0, rowHeight)
        let rows = arrangedRows(in: width, subviews: subviews)
        guard !rows.isEmpty else { return CGSize(width: width, height: 0) }
        return CGSize(
            width: width,
            height: rows.reduce(CGFloat(0)) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangedRows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.width, height: row.height)
                )
                x += item.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrangedRows(in availableWidth: CGFloat, subviews: Subviews) -> [GridRowPlacement] {
        guard !subviews.isEmpty else { return [] }
        let maxWidth = max(availableWidth, rowHeight)
        var rows: [[GridItemSeed]] = []
        var row: [GridItemSeed] = []
        var aspectSum = CGFloat(0)

        for index in subviews.indices {
            let aspect = ImageAspectReader.clamped(subviews[index][ImageAspectLayoutKey.self])
            let nextAspectSum = aspectSum + aspect
            let nextWidth = nextAspectSum * rowHeight + CGFloat(row.count) * spacing

            if !row.isEmpty, nextWidth > maxWidth {
                rows.append(row)
                row = [GridItemSeed(index: index, aspect: aspect)]
                aspectSum = aspect
            } else {
                row.append(GridItemSeed(index: index, aspect: aspect))
                aspectSum = nextAspectSum
            }
        }

        if !row.isEmpty {
            rows.append(row)
        }

        return rows.enumerated().map { index, row in
            makeRow(row, in: maxWidth, fillsWidth: index != rows.count - 1)
        }
    }

    private func makeRow(_ row: [GridItemSeed], in availableWidth: CGFloat, fillsWidth: Bool) -> GridRowPlacement {
        guard !row.isEmpty else {
            return GridRowPlacement(height: rowHeight, items: [])
        }
        let spacingWidth = CGFloat(max(0, row.count - 1)) * spacing
        let aspectSum = row.reduce(CGFloat(0)) { $0 + $1.aspect }
        let targetWidth = max(availableWidth - spacingWidth, 1)
        let height = fillsWidth && aspectSum > 0 ? targetWidth / aspectSum : rowHeight
        let items = row.map {
            GridItemPlacement(index: $0.index, width: $0.aspect * height)
        }
        return GridRowPlacement(height: height, items: items)
    }
}

private struct GridRowPlacement {
    let height: CGFloat
    let items: [GridItemPlacement]
}

private struct GridItemSeed {
    let index: Int
    let aspect: CGFloat
}

private struct GridItemPlacement {
    let index: Int
    let width: CGFloat
}

struct AdaptiveImageGridItem<Content: View>: View {
    let asset: ImageAsset
    @ViewBuilder var content: () -> Content

    @State private var imageAspect: CGFloat

    init(asset: ImageAsset, @ViewBuilder content: @escaping () -> Content) {
        self.asset = asset
        self.content = content
        _imageAspect = State(initialValue: ImageAspectReader.initialAspect(for: asset))
    }

    var body: some View {
        content()
            .layoutValue(key: ImageAspectLayoutKey.self, value: imageAspect)
            .task(id: asset.fileURL?.path ?? asset.thumbnailURL?.path ?? asset.id) {
                imageAspect = await ImageAspectReader.aspectRatio(for: asset)
            }
    }
}
