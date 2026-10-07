import Foundation
import Security

public struct KeychainError: Error, Equatable {
    public let status: OSStatus
}

/// One Keychain item holding the credentials, in an access group the
/// share extension can read too.
public struct KeychainCredentialStore: CredentialStore {
    /// The store app and extension share. The group name comes from the
    /// Info.plist, which the build fills with the team's identifier prefix.
    public static let shared = KeychainCredentialStore(
        accessGroup: Bundle.main.object(forInfoDictionaryKey: "HrcekKeychainGroup") as? String)

    private let service: String
    private let accessGroup: String?

    public init(service: String = "app.hrcek.credentials", accessGroup: String?) {
        self.service = service
        self.accessGroup = accessGroup
    }

    private var query: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "default",
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    public func load() throws -> Credentials? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            Log.auth.error("Keychain read failed: \(status)")
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }

    public func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // The extension runs while the phone is in use; never after a restart before unlock.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            Log.auth.error("Keychain write failed: \(status)")
            throw KeychainError(status: status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}
