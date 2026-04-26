import SwiftUI

struct ImageActionsBar: View {
    let asset: ImageAsset
    let onEdit: () -> Void
    let onRegenerate: () -> Void
    let onUseAsReference: () -> Void
    let onExport: () -> Void
    let onPick: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            actionButton("수정", system: "pencil.tip.crop.circle", action: onEdit)
                .disabled(!asset.hasFile)
            actionButton("다시 만들기", system: "arrow.triangle.2.circlepath", action: onRegenerate)
            actionButton("레퍼런스", system: "photo.on.rectangle", action: onUseAsReference)
                .disabled(!asset.hasFile)
            actionButton("내보내기", system: "square.and.arrow.up", action: onExport)
                .disabled(!asset.hasFile)
            actionButton(
                asset.status == .picked ? "Picked 해제" : "Pick",
                system: asset.status == .picked ? "bookmark.slash" : "bookmark",
                action: onPick
            )
            .disabled(!asset.hasFile)

            Spacer()

            actionButton("삭제", system: "trash", role: .destructive, action: onDelete)
        }
        .controlSize(.large)
        .buttonStyle(.glass)
    }

    private func actionButton(
        _ title: String,
        system: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: system)
        }
    }
}
