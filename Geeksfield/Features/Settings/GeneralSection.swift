import SwiftUI

struct GeneralSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let l10n = appState.l10n
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.settingsGeneral)
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Text(l10n.language)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { appState.language },
                        set: { appState.setLanguage($0) }
                    )) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
    }
}
