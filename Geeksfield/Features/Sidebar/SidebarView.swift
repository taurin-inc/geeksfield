import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingSettings = false
    @State private var newProjectSheet = false
    @State private var newProjectName = ""

    var body: some View {
        ZStack {
            if appState.projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newProjectSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help("새 프로젝트")
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
            Button("프로젝트 내보내기") {
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
            Text("프로젝트 없음")
                .font(.headline)
            Text("툴바의 + 버튼으로 시작하세요")
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
            .help("설정")

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
        .help("\(provider.displayName) \(connected ? "연결됨" : "미연결")")
    }

    private var newProjectForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 프로젝트").font(.title2).fontWeight(.semibold)
            TextField("이름", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("취소") { newProjectSheet = false }
                    .buttonStyle(.glass)
                Button("만들기") {
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
