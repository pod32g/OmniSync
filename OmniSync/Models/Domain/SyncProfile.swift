import Foundation

struct SyncProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String // Legacy - kept for backward compatibility
    var username: String // Legacy - kept for backward compatibility
    var remotePath: String // Legacy - kept for backward compatibility
    var localPath: String
    var filter: String
    var customFilterPatterns: String
    var optimizeForSpeed: Bool
    var deleteRemote: Bool
    var destinations: [RemoteDestination]

    enum CodingKeys: String, CodingKey {
        case id, name, host, username, remotePath, localPath, filter, customFilterPatterns, optimizeForSpeed, deleteRemote, destinations
    }

    init(
        id: UUID,
        name: String,
        host: String,
        username: String,
        remotePath: String,
        localPath: String,
        filter: String,
        customFilterPatterns: String,
        optimizeForSpeed: Bool,
        deleteRemote: Bool,
        destinations: [RemoteDestination] = []
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.remotePath = remotePath
        self.localPath = localPath
        self.filter = filter
        self.customFilterPatterns = customFilterPatterns
        self.optimizeForSpeed = optimizeForSpeed
        self.deleteRemote = deleteRemote

        // If destinations provided, use them; otherwise create from legacy fields
        if destinations.isEmpty && !host.isEmpty {
            self.destinations = [RemoteDestination(host: host, username: username, remotePath: remotePath)]
        } else {
            self.destinations = destinations
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        username = try container.decode(String.self, forKey: .username)
        remotePath = try container.decode(String.self, forKey: .remotePath)
        localPath = try container.decode(String.self, forKey: .localPath)
        filter = try container.decode(String.self, forKey: .filter)
        customFilterPatterns = try container.decode(String.self, forKey: .customFilterPatterns)
        optimizeForSpeed = try container.decodeIfPresent(Bool.self, forKey: .optimizeForSpeed) ?? false
        deleteRemote = try container.decodeIfPresent(Bool.self, forKey: .deleteRemote) ?? false

        // Try to decode destinations; if not present, migrate from legacy fields
        if let decodedDestinations = try? container.decodeIfPresent([RemoteDestination].self, forKey: .destinations), !decodedDestinations.isEmpty {
            destinations = decodedDestinations
        } else if !host.isEmpty {
            // Migrate legacy profile to new format
            destinations = [RemoteDestination(host: host, username: username, remotePath: remotePath)]
        } else {
            destinations = []
        }
    }
}
