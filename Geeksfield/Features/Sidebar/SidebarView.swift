import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSettings = false
    @State private var newProjectSheet = false
    @State private var newProjectName = ""
    @State private var renamingProject: Project?
    @State private var renameProjectName = ""
    @State private var draggingProjectID: String?
    @State private var dropIndex: Int?

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
        .sheet(item: $renamingProject) { project in
            renameProjectForm(project)
                .environment(appState)
        }
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(appState.projects.enumerated()), id: \.element.id) { index, project in
                    insertionLine(visible: dropIndex == index)
                    projectRow(project)
                        .opacity(draggingProjectID == project.id ? 0.45 : 1)
                        .onDrag {
                            draggingProjectID = project.id
                            return NSItemProvider(object: project.id as NSString)
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: ProjectRowDropDelegate(
                                index: index,
                                projectID: project.id,
                                draggingProjectID: $draggingProjectID,
                                dropIndex: $dropIndex,
                                appState: appState
                            )
                        )
                }
                insertionLine(visible: dropIndex == appState.projects.count)
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
            Button(appState.l10n.renameProject) {
                renamingProject = project
                renameProjectName = project.name
            }
            Button(appState.l10n.exportProject) {
                appState.selectedProjectID = project.id
                appState.exportSelectedProject()
            }
        }
    }

    private func insertionLine(visible: Bool) -> some View {
        Capsule()
            .fill(visible ? Color.accentColor : Color.clear)
            .frame(height: 2)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
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
                providerDot(.codex)
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

    private func renameProjectForm(_ project: Project) -> some View {
        let l10n = appState.l10n
        return VStack(alignment: .leading, spacing: 16) {
            Text(l10n.renameProject).font(.title2).fontWeight(.semibold)
            TextField(l10n.name, text: $renameProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(l10n.cancel) { renamingProject = nil }
                    .buttonStyle(.glass)
                Button(l10n.done) {
                    appState.renameProject(project, to: renameProjectName)
                    renamingProject = nil
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(renameProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

private struct ProjectRowDropDelegate: DropDelegate {
    let index: Int
    let projectID: String
    @Binding var draggingProjectID: String?
    @Binding var dropIndex: Int?
    let appState: AppState

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropIndex(info: info)
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        updateDropIndex(info: info)
    }

    func dropExited(info: DropInfo) {
        dropIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggingProjectID = nil
            dropIndex = nil
        }
        guard draggingProjectID != nil else {
            return false
        }
        appState.persistCurrentProjectOrder()
        return true
    }

    private func updateDropIndex(info: DropInfo) {
        guard let sourceID = draggingProjectID, sourceID != projectID else {
            dropIndex = nil
            return
        }
        guard let insertion = insertionIndex(info: info) else {
            dropIndex = nil
            return
        }
        dropIndex = insertion
        appState.previewMoveProject(id: sourceID, toInsertionIndex: insertion)
    }

    private func insertionIndex(info: DropInfo) -> Int? {
        guard draggingProjectID != projectID else { return nil }
        return info.location.y < 28 ? index : index + 1
    }
}
