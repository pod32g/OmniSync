import Foundation

final class ProfileRepository {
    private let persistenceService: PersistenceServiceProtocol
    private let storageKey = "syncProfiles"

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func loadProfiles() -> [SyncProfile] {
        persistenceService.load([SyncProfile].self, forKey: storageKey) ?? []
    }

    func saveProfiles(_ profiles: [SyncProfile]) {
        persistenceService.save(profiles, forKey: storageKey)
    }

    func addProfile(_ profile: SyncProfile) {
        var profiles = loadProfiles()
        profiles.append(profile)
        saveProfiles(profiles)
    }

    func updateProfile(_ profile: SyncProfile) {
        var profiles = loadProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles(profiles)
        }
    }

    func deleteProfile(id: UUID) {
        var profiles = loadProfiles()
        profiles.removeAll { $0.id == id }
        saveProfiles(profiles)
    }
}
