import SwiftUI

struct GalleryGrid: View {
    let assets: [ImageAsset]
    let columns: Int
    var onSelect: (ImageAsset) -> Void = { _ in }

    var body: some View {
        let layout = Array(repeating: GridItem(.flexible(), spacing: 8), count: max(columns, 1))
        ScrollView {
            LazyVGrid(columns: layout, spacing: 8) {
                ForEach(assets) { asset in
                    Button {
                        onSelect(asset)
                    } label: {
                        ImageTileView(asset: asset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}
