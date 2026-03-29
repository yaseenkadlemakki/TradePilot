import Foundation
import Security

// MARK: - Key constants

extension KeychainManager {
    enum ServiceKey {
        static let polygonAPIKey        = "polygon_api_key"
        static let unusualWhalesAPIKey  = "unusual_whales_api_key"
        static let redditClientID       = "reddit_client_id"
        static let redditClientSecret   = "reddit_client_secret"
        static let newsAPIKey           = "news_api_key"
        static let claudeAPIKey         = "claude_api_key"
    }
}

// MARK: - Errors

enum KeychainError: Error {
    case unexpectedData
    case unhandledError(status: OSStatus)
}

// MARK: - Manager

/// Wraps Security framework Keychain operations for secure BYO API key storage.
struct KeychainManager {
    private let account = "com.tradepilot.app"

    /// Saves (or replaces) `value` for `service`. Throws on failure.
    func save(key: String, service: String) throws {
        let data = Data(key.utf8)

        // Try update first
        let updateQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let updateAttr: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttr as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Not found — add new item
            let addQuery: [CFString: Any] = [
                kSecClass:            kSecClassGenericPassword,
                kSecAttrService:      service,
                kSecAttrAccount:      account,
                kSecValueData:        data,
                kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledError(status: updateStatus)
        }
    }

    /// Loads the stored value for `service`, or returns `nil` if absent.
    func load(service: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes the stored value for `service`. Silent if not found.
    func delete(service: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
