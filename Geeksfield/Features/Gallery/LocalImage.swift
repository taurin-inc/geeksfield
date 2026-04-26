import AppKit
import SwiftUI

/// Reliable file:// image loader. AsyncImage hangs on sandboxed file URLs;
/// passing NSImage across actor boundaries also misbehaves under Swift 6 strict
/// concurrency. So we read the bytes off-main as Sendable Data, then construct
/// NSImage on the main actor.
struct LocalImage: View {
    let url: URL
    var contentMode: ContentMode = .fit

    @State private var image: NSImage?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text(errorMessage)
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

    private func load() async {
        let url = self.url
        let path = url.path

        // Verify the file exists before doing anything else — surfacing this
        // up front beats spinning forever on a missing file.
        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "파일을 찾을 수 없습니다: \(url.lastPathComponent)"
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
                self.errorMessage = "이미지 디코딩 실패"
            }
        } catch {
            self.errorMessage = "읽기 실패: \(error.localizedDescription)"
        }
    }
}
