import SwiftUI

struct GalleryView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: GalleryFilter = .all
    @State private var columns: Int = 4
    @State private var failedAsset: ImageAsset?

    var body: some View {
        VStack(spacing: 0) {
            if currentThreadAsset == nil {
                toolbar
                Divider()
            }

            content
                .frame(maxHeight: .infinity)

            PromptBarView()
        }
        .navigationSplitViewColumnWidth(min: 480, ideal: 720)
        .failedImageAlert(asset: $failedAsset)
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
        } else if let asset = currentThreadAsset {
            ImageThreadWorkspaceView(asset: asset)
        } else if filteredAssets.isEmpty {
            ContentUnavailableView(
                l10n.noImagesYet,
                systemImage: "wand.and.sparkles",
                description: Text(l10n.tryFromPromptBar)
            )
        } else {
            IterationBoardView(groups: filteredGroups, columns: columns) { asset in
                select(asset)
            }
        }
    }

    private var currentThreadAsset: ImageAsset? {
        guard let selectedProjectID = appState.selectedProjectID,
              let asset = appState.presentedAsset,
              asset.metadata.projectID == selectedProjectID else {
            return nil
        }
        return appState.asset(withID: asset.id, in: selectedProjectID) ?? asset
    }

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusTabs(filter: $filter)
            Text(appState.l10n.iterationBoard)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
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

    private var filteredGroups: [IterationThreadGroup] {
        let groups = IterationThreadGroup.lineages(appState.selectedProjectRuns)
        switch filter {
        case .all:
            return groups
        case .picked:
            return groups.compactMap { group in
                group.filteringAssets { $0.status == .picked }
            }
        }
    }

    private func select(_ asset: ImageAsset) {
        if asset.status == .failed {
            failedAsset = asset
        } else {
            appState.presentedAsset = asset
        }
    }
}
