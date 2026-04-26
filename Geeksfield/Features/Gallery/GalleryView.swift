import SwiftUI

struct GalleryView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: GalleryFilter = .all
    @State private var columns: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            content
                .frame(maxHeight: .infinity)

            PromptBarView()
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationSplitViewColumnWidth(min: 480, ideal: 720)
    }

    @ViewBuilder
    private var content: some View {
        let l10n = appState.l10n
        if appState.selectedProjectID == nil {
            ContentUnavailableView(
                l10n.selectAProject,
                systemImage: "folder",
                description: Text(l10n.pickProjectFromSidebar)
            )
        } else if filteredAssets.isEmpty {
            ContentUnavailableView(
                l10n.noImagesYet,
                systemImage: "wand.and.sparkles",
                description: Text(l10n.tryFromPromptBar)
            )
        } else {
            GalleryGrid(assets: filteredAssets, columns: columns) { asset in
                appState.presentedAsset = asset
            }
        }
    }

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusTabs(filter: $filter)
            Spacer()
            GridDensityControl(columns: $columns)
        }
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filteredAssets: [ImageAsset] {
        let all = appState.selectedProjectAssets
        switch filter {
        case .all: return all
        case .picked: return all.filter { $0.status == .picked }
        }
    }
}
