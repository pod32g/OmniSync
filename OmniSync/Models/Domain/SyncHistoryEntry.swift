import Foundation

struct SyncHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let success: Bool
    let direction: SyncDirection
    let remotePath: String
    let localPath: String
    let filter: String
    let customFilterPatterns: String
    let logLines: [String]
    let bytesTransferred: Int64
    let averageSpeedMBps: Double

    enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, success, direction, remotePath, localPath, filter, customFilterPatterns, logLines
        case bytesTransferred, averageSpeedMBps
    }

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        success: Bool,
        direction: SyncDirection,
        remotePath: String,
        localPath: String,
        filter: String,
        customFilterPatterns: String,
        logLines: [String],
        bytesTransferred: Int64 = 0,
        averageSpeedMBps: Double = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.success = success
        self.direction = direction
        self.remotePath = remotePath
        self.localPath = localPath
        self.filter = filter
        self.customFilterPatterns = customFilterPatterns
        self.logLines = logLines
        self.bytesTransferred = bytesTransferred
        self.averageSpeedMBps = averageSpeedMBps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        success = try container.decode(Bool.self, forKey: .success)
        direction = try container.decode(SyncDirection.self, forKey: .direction)
        remotePath = try container.decode(String.self, forKey: .remotePath)
        localPath = try container.decode(String.self, forKey: .localPath)
        filter = try container.decode(String.self, forKey: .filter)
        customFilterPatterns = try container.decode(String.self, forKey: .customFilterPatterns)
        logLines = try container.decode([String].self, forKey: .logLines)
        // Backward compatibility: default to 0 if not present
        bytesTransferred = try container.decodeIfPresent(Int64.self, forKey: .bytesTransferred) ?? 0
        averageSpeedMBps = try container.decodeIfPresent(Double.self, forKey: .averageSpeedMBps) ?? 0
    }
}
