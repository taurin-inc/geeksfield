import SwiftUI

enum GalleryFilter: String, Hashable, CaseIterable, Identifiable {
    case all, picked

    var id: Self { self }
    func label(_ l10n: L10n) -> String {
        switch self {
        case .all: return l10n.all
        case .picked: return l10n.picked
        }
    }
}

/// Liquid-glass two-option pill switch. Sized to its content (no fill).
struct StatusTabs: View {
    @Environment(AppState.self) private var appState
    @Binding var filter: GalleryFilter
    @Namespace private var indicator

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 4) {
                ForEach(GalleryFilter.allCases) { option in
                    pill(option)
                }
            }
            .padding(3)
        }
        .glassEffect(.regular, in: Capsule())
        .fixedSize()
    }

    private func pill(_ option: GalleryFilter) -> some View {
        let isSelected = filter == option
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                filter = option
            }
        } label: {
            Text(option.label(appState.l10n))
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.85))
                            .matchedGeometryEffect(id: "selectedPill", in: indicator)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
