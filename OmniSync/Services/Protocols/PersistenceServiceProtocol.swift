import Foundation

protocol PersistenceServiceProtocol {
    // UserDefaults
    func save<T>(_ value: T, forKey key: String) where T: Encodable
    func load<T>(_ type: T.Type, forKey key: String) -> T? where T: Decodable
    func saveString(_ value: String, forKey key: String)
    func loadString(forKey key: String) -> String?
    func saveBool(_ value: Bool, forKey key: String)
    func loadBool(forKey key: String) -> Bool?
    func saveInt(_ value: Int, forKey key: String)
    func loadInt(forKey key: String) -> Int?

    // Keychain
    func savePassword(_ password: String) throws
    func loadPassword() throws -> String
    func deletePassword() throws
}
