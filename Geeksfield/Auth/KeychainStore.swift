import Foundation

enum KeychainError: Error {
    case encodingFailed
    case ioFailed(Error)
    case storageUnavailable(Error)
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
        var dict = (try? readDict()) ?? [:]
        dict[provider.rawValue] = key
        try writeDict(dict)
    }

    func apiKey(for provider: Provider) -> String? {
        (try? readDict())?[provider.rawValue]
    }

    func deleteAPIKey(for provider: Provider) throws {
        var dict = (try? readDict()) ?? [:]
        dict.removeValue(forKey: provider.rawValue)
        try writeDict(dict)
    }

    // MARK: - Storage

    private func resolveFileURL() throws -> URL {
        let fm = FileManager.default
        let dir: URL
        do {
            dir = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw KeychainError.storageUnavailable(error)
        }
        let appDir = dir.appendingPathComponent(service, isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            do {
                try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                throw KeychainError.storageUnavailable(error)
            }
        }
        return appDir.appendingPathComponent("api-keys.json")
    }

    private func readDict() throws -> [String: String] {
        let url = try resolveFileURL()
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func writeDict(_ dict: [String: String]) throws {
        let url = try resolveFileURL()
        do {
            let data = try JSONEncoder().encode(dict)
            try data.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            throw KeychainError.ioFailed(error)
        }
    }
}
