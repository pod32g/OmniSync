import Foundation

struct RemoteDestination: Identifiable, Codable, Equatable {
    let id: UUID
    var host: String
    var username: String
    var remotePath: String

    init(id: UUID = UUID(), host: String, username: String, remotePath: String) {
        self.id = id
        self.host = host
        self.username = username
        self.remotePath = remotePath
    }
}
