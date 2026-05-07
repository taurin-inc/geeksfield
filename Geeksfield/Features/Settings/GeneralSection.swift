import SwiftUI

struct GeneralSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let l10n = appState.l10n
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.settingsGeneral)
                .font(.headline)

            SettingsCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        SettingsIconTile(systemName: "globe")

                        Text(l10n.language)
                            .font(.callout.weight(.medium))

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

                    if appState.autoUpdater.isEnabled {
                        Divider()
                            .padding(.leading, 48)
                            .padding(.vertical, 12)

                        HStack(spacing: 12) {
                            SettingsIconTile(systemName: "arrow.triangle.2.circlepath")

                            Text(l10n.updates)
                                .font(.callout.weight(.medium))

                            Spacer()

                            Button(l10n.checkForUpdates) {
                                checkForUpdates()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private func checkForUpdates() {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            appState.autoUpdater.checkForUpdates()
        }
    }
}
