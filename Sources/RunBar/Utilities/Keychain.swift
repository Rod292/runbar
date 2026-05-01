import Foundation
import Security

/// Wrapper Keychain minimal — pour stocker le refresh token Strava (Phase 6).
/// Service: `com.rodrigue.runbar.strava`.
public enum Keychain {
    public static let stravaService = "com.rodrigue.runbar.strava"

    public static func set(_ value: String, account: String, service: String = stravaService) throws {
        let data = Data(value.utf8)
        // Supprime l'existant (uniqueness sur service+account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.osStatus(status) }
    }

    public static func get(account: String, service: String = stravaService) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func remove(account: String, service: String = stravaService) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum KeychainError: Error {
    case osStatus(OSStatus)
}
