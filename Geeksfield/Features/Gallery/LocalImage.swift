import AppKit
import SwiftUI

/// Reliable file:// image loader. AsyncImage hangs on sandboxed file URLs;
/// passing NSImage across actor boundaries also misbehaves under Swift 6 strict
/// concurrency. So we read the bytes off-main as Sendable Data, then construct
/// NSImage on the main actor.
struct LocalImage: View {
    enum LoadError: Equatable {
        case fileNotFound(String)
        case decodingFailed
        case readFailed(String)
    }

    let url: URL
    var contentMode: ContentMode = .fit

    @Environment(AppState.self) private var appState
    @State private var image: NSImage?
    @State private var loadError: LoadError?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let loadError {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text(message(for: loadError))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }
            } else {
                ProgressView()
            }
        }
        .task(id: url.path) { await load() }
    }

    private func message(for err: LoadError) -> String {
        switch err {
        case .fileNotFound(let name): return appState.l10n.fileNotFound(name)
        case .decodingFailed: return appState.l10n.imageDecodeFailed
        case .readFailed(let msg): return appState.l10n.readFailed(msg)
        }
    }

    private func load() async {
        let url = self.url
        let path = url.path

        // Verify the file exists before doing anything else — surfacing this
        // up front beats spinning forever on a missing file.
        guard FileManager.default.fileExists(atPath: path) else {
            loadError = .fileNotFound(url.lastPathComponent)
            return
        }

        do {
            let data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
            if Task.isCancelled { return }
            if let nsImage = NSImage(data: data) {
                self.image = nsImage
            } else {
                self.loadError = .decodingFailed
            }
        } catch {
            self.loadError = .readFailed(error.localizedDescription)
        }
    }
}
