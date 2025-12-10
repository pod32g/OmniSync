import Foundation

final class GroupRepository {
    private let persistenceService: PersistenceServiceProtocol
    private let storageKey = "syncGroups"

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
    }

    func loadGroups() -> [SyncGroup] {
        persistenceService.load([SyncGroup].self, forKey: storageKey) ?? []
    }

    func saveGroups(_ groups: [SyncGroup]) {
        persistenceService.save(groups, forKey: storageKey)
    }

    func addGroup(_ group: SyncGroup) {
        var groups = loadGroups()
        groups.append(group)
        saveGroups(groups)
    }

    func updateGroup(_ group: SyncGroup) {
        var groups = loadGroups()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups(groups)
        }
    }

    func deleteGroup(id: UUID) {
        var groups = loadGroups()
        groups.removeAll { $0.id == id }
        saveGroups(groups)
    }
}
