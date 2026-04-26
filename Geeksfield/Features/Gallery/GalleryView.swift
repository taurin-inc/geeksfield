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
        .navigationSplitViewColumnWidth(min: 480, ideal: 720)
    }

    @ViewBuilder
    private var content: some View {
        if appState.selectedProjectID == nil {
            ContentUnavailableView(
                "프로젝트를 선택하세요",
                systemImage: "folder",
                description: Text("왼쪽 사이드바에서 프로젝트를 고르거나 새로 만드세요.")
            )
        } else if filteredAssets.isEmpty {
            ContentUnavailableView(
                "아직 이미지가 없습니다",
                systemImage: "wand.and.sparkles",
                description: Text("아래 프롬프트 바에서 생성해 보세요.")
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
