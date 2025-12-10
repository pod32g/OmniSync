import Foundation

struct SyncGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var profileIDs: [UUID]

    init(id: UUID = UUID(), name: String, profileIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.profileIDs = profileIDs
    }
}
