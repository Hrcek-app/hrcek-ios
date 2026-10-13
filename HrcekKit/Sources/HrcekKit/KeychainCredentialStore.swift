import Foundation
import Security

public struct KeychainError: Error, Equatable {
    public let status: OSStatus
}

/// One generic-password item, in an access group the share extension can
/// read too.
struct KeychainItem: Sendable {
    let service: String
    let accessGroup: String?

    /// The group app and extension share. Its name comes from the
    /// Info.plist, which the build fills with the team's identifier prefix.
    static let sharedGroup =
        Bundle.main.object(forInfoDictionaryKey: "HrcekKeychainGroup") as? String

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

    func read() throws -> Data? {
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
        return data
    }

    func write(_ data: Data) throws {
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

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

/// The credentials, as one Keychain item app and extension share.
public struct KeychainCredentialStore: CredentialStore {
    public static let shared = KeychainCredentialStore(accessGroup: KeychainItem.sharedGroup)

    private let item: KeychainItem

    public init(service: String = "app.hrcek.credentials", accessGroup: String?) {
        item = KeychainItem(service: service, accessGroup: accessGroup)
    }

    public func load() throws -> Credentials? {
        guard let data = try item.read() else { return nil }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }

    public func save(_ credentials: Credentials) throws {
        try item.write(try JSONEncoder().encode(credentials))
    }

    public func delete() throws {
        try item.delete()
    }
}
