import Foundation
import Security

final class PersistenceService: PersistenceServiceProtocol {
    private let defaults = UserDefaults.standard
    private let keychainAccount = "omnisync.password"
    private let keychainService = "com.omnisync.app"

    // MARK: - UserDefaults

    func save<T>(_ value: T, forKey key: String) where T: Encodable {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    func load<T>(_ type: T.Type, forKey key: String) -> T? where T: Decodable {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func saveString(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func loadString(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func saveBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func loadBool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    func saveInt(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func loadInt(forKey key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    // MARK: - Keychain

    func savePassword(_ password: String) throws {
        if password.isEmpty {
            try deletePassword()
            return
        }

        let encoded = password.data(using: .utf8) ?? Data()
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService
        ]

        let update: [String: Any] = [kSecValueData as String: encoded]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = encoded
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func loadPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return "" }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        guard let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            return ""
        }
        return password
    }

    func deletePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
