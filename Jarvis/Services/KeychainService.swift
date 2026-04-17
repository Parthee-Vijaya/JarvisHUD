import Foundation
import Security

class KeychainService: @unchecked Sendable {
    private let serviceName = Constants.keychainService
    private let accountName = Constants.keychainAccount
    private var cachedKey: String?

    func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            cachedKey = key
        } else {
            LoggingService.shared.log("Keychain save failed: \(status)", level: .error)
        }
        return status == errSecSuccess
    }

    func getAPIKey() -> String? {
        if let cachedKey { return cachedKey }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        let key = String(data: data, encoding: .utf8)
        cachedKey = key
        return key
    }

    @discardableResult
    func deleteAPIKey() -> Bool {
        cachedKey = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    var hasAPIKey: Bool { getAPIKey() != nil }
}
