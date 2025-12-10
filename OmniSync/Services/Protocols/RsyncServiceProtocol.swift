import Foundation

struct RsyncConfig {
    let host: String
    let username: String
    let password: String
    let remotePath: String
    let localPath: String
    let syncDirection: SyncDirection
    let filterArgs: [String]
    let quietMode: Bool
    let logFileURL: URL
    let strictHostKeyChecking: Bool
    let dryRun: Bool
    let bandwidthLimitKBps: Int
    let resumePartials: Bool
    let optimizeForSpeed: Bool
    let deleteRemoteFiles: Bool
}

protocol RsyncServiceProtocol {
    func run(
        config: RsyncConfig,
        onLog: @escaping ([String]) -> Void,
        onFile: @escaping (String) -> Void,
        onSpeed: @escaping (String) -> Void,
        onProgress: @escaping (Double?) -> Void,
        onStart: @escaping () -> Void,
        onCompletion: @escaping (Bool) -> Void
    )

    func cancel()

    func buildFilterArgs(
        selectedFilter: FileFilter,
        customFilterPatterns: String,
        excludePatterns: String
    ) -> [String]

    func testConnection(
        host: String,
        username: String,
        password: String,
        strictHostKeyChecking: Bool,
        completion: @escaping (ConnectionStatus) -> Void
    )
}
