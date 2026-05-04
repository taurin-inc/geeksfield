import Foundation

enum KeychainError: Error {
    case encodingFailed
    case ioFailed(Error)
}

/// Legacy credential store backed by a sandbox-private file in Application Support.
///
/// We initially used the macOS keychain, but ad-hoc-signed debug builds get a
/// fresh code signature on every rebuild — and the keychain ACL stored on the
/// item refers to the previous binary's signature. Each new build then prompts
/// the user for their login password to rebind access. Storing keys inside the
/// app's sandbox container avoids the ACL entirely; sandbox isolation already
/// prevents other apps from reading the file.
struct KeychainStore: Sendable {
    let service: String

    init(service: String = "com.geeksfield.app") {
        self.service = service
    }

    func setAPIKey(_ key: String, for provider: Provider) throws {
        var dict = readDict()
        dict[provider.rawValue] = key
        try writeDict(dict)
    }

    func apiKey(for provider: Provider) -> String? {
        readDict()[provider.rawValue]
    }

    func deleteAPIKey(for provider: Provider) throws {
        var dict = readDict()
        dict.removeValue(forKey: provider.rawValue)
        try writeDict(dict)
    }

    // MARK: - Storage

    private var fileURL: URL {
        let fm = FileManager.default
        let dir = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appDir = dir.appendingPathComponent(service, isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("api-keys.json")
    }

    private func readDict() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: String]) throws {
        do {
            let data = try JSONEncoder().encode(dict)
            try data.write(to: fileURL, options: [.atomic])
            // Restrict to owner read/write (0o600).
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            throw KeychainError.ioFailed(error)
        }
    }
}
