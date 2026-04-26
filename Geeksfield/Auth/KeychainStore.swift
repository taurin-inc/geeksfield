import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

struct KeychainStore: Sendable {
    let service: String

    init(service: String = "com.geeksfield.app") {
        self.service = service
    }

    func setAPIKey(_ key: String, for provider: Provider) throws {
        try set(account: provider.rawValue, value: key)
    }

    func apiKey(for provider: Provider) -> String? {
        try? get(account: provider.rawValue)
    }

    func deleteAPIKey(for provider: Provider) throws {
        try delete(account: provider.rawValue)
    }

    // MARK: - Generic helpers

    private func set(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        // Delete-then-add is more reliable than SecItemUpdate which can silently
        // fail when accessibility attributes don't match. The cost is a single
        // extra syscall; consistency wins.
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func get(account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let str = String(data: data, encoding: .utf8) else {
                return nil
            }
            return str
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func delete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
