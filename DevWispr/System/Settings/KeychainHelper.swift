//
//  KeychainHelper.swift
//  DevWispr
//

import Foundation
import os.log
import Security

private let logger = Logger(subsystem: "com.devwispr.app", category: "Keychain")

enum KeychainHelper {

    static func save(service: String, account: String, data: String) -> Bool {
        guard let encoded = data.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Try to update an existing item first.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        // Item doesn't exist yet — add it.
        var addQuery = query
        addQuery.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("Keychain save failed: \(addStatus)")
        }
        return addStatus == errSecSuccess
    }

    static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain load failed: \(status)")
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed: \(status)")
        }
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
