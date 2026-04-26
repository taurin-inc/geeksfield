import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSettings = false
    @State private var newProjectSheet = false
    @State private var newProjectName = ""

    var body: some View {
        let l10n = appState.l10n
        ZStack {
            if appState.projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle(l10n.projects)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newProjectSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help(l10n.newProject)
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(appState)
        }
        .sheet(isPresented: $newProjectSheet) {
            newProjectForm
                .environment(appState)
        }
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(appState.projects) { project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
    }

    private func projectRow(_ project: Project) -> some View {
        let isSelected = appState.selectedProjectID == project.id
        return Button {
            appState.selectedProjectID = project.id
        } label: {
            ProjectRowView(
                project: project,
                imageCount: appState.assetsByProject[project.id]?.count ?? 0
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
        )
        .contextMenu {
            Button(appState.l10n.exportProject) {
                appState.selectedProjectID = project.id
                appState.exportSelectedProject()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(appState.l10n.noProjects)
                .font(.headline)
            Text(appState.l10n.startWithPlus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.glass)
            .help(appState.l10n.settings)

            Spacer()

            HStack(spacing: 8) {
                providerDot(.openai)
                providerDot(.gemini)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func providerDot(_ provider: Provider) -> some View {
        let connected = appState.connectedProviders.contains(provider)
        return HStack(spacing: 5) {
            Circle()
                .fill(connected ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: 7, height: 7)
            Text(provider.displayName)
                .font(.caption)
                .foregroundStyle(connected ? .primary : .secondary)
        }
        .help("\(provider.displayName) \(connected ? appState.l10n.connected : appState.l10n.notConnected)")
    }

    private var newProjectForm: some View {
        let l10n = appState.l10n
        return VStack(alignment: .leading, spacing: 16) {
            Text(l10n.newProject).font(.title2).fontWeight(.semibold)
            TextField(l10n.name, text: $newProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(l10n.cancel) { newProjectSheet = false }
                    .buttonStyle(.glass)
                Button(l10n.create) {
                    let name = newProjectName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    appState.createProject(name: name)
                    newProjectName = ""
                    newProjectSheet = false
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
