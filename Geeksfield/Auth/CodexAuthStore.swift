import Foundation
import Darwin

struct CodexAuth: Sendable {
    let accessToken: String
    let accountID: String
}

struct CodexAuthStore: Sendable {
    var authURL: URL {
        Self.realHomeDirectory
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")
    }

    private static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()),
           let home = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    func isSignedIn() -> Bool {
        (try? load()) != nil
    }

    func load() throws -> CodexAuth {
        let data = try Data(contentsOf: authURL)
        let decoded = try JSONDecoder().decode(AuthFile.self, from: data)
        guard let accessToken = decoded.tokens.accessToken,
              let accountID = decoded.tokens.accountID,
              !accessToken.isEmpty,
              !accountID.isEmpty else {
            throw CodexAuthError.missingToken
        }
        return CodexAuth(accessToken: accessToken, accountID: accountID)
    }

    private struct AuthFile: Decodable {
        let tokens: Tokens
    }

    private struct Tokens: Decodable {
        let accessToken: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }
}

enum CodexAuthError: Error, LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Codex login was found, but ~/.codex/auth.json is missing access_token or account_id."
        }
    }
}
