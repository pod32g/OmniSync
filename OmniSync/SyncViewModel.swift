import Foundation
import Combine
import AppKit
import Security
import UserNotifications
import UniformTypeIdentifiers
import Network

enum ExportFormat {
    case csv
    case json

    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

enum FileFilter: String, CaseIterable, Identifiable {
    case all
    case video
    case photo
    case documents
    case audio
    case archives
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All files"
        case .video: return "Videos"
        case .photo: return "Photos"
        case .documents: return "Text & Docs"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .custom: return "Custom patterns"
        }
    }

    var patterns: [String] {
        switch self {
        case .all: return []
        case .video: return ["*.mp4", "*.mov", "*.mkv", "*.avi", "*.m4v", "*.mts", "*.m2ts", "*.webm", "*.mpeg", "*.mpg", "*.3gp"]
        case .photo: return ["*.jpg", "*.jpeg", "*.png", "*.heic", "*.heif", "*.gif", "*.tif", "*.tiff", "*.bmp", "*.raw", "*.dng", "*.cr2", "*.nef", "*.arw", "*.raf"]
        case .documents: return ["*.txt", "*.md", "*.rtf", "*.pdf", "*.doc", "*.docx", "*.pages", "*.csv", "*.xls", "*.xlsx", "*.ppt", "*.pptx", "*.key"]
        case .audio: return ["*.mp3", "*.flac", "*.aac", "*.m4a", "*.wav", "*.aiff", "*.aif", "*.ogg", "*.opus", "*.wma"]
        case .archives: return ["*.zip", "*.tar", "*.gz", "*.tgz", "*.7z", "*.rar", "*.bz2", "*.xz", "*.iso"]
        case .custom: return []
        }
    }

    var example: String {
        switch self {
        case .all: return "No filtering"
        case .video: return "*.mp4, *.mov, *.mkv"
        case .photo: return "*.jpg, *.png, *.heic"
        case .documents: return "*.txt, *.pdf, *.docx"
        case .audio: return "*.mp3, *.flac, *.wav"
        case .archives: return "*.zip, *.tar, *.rar"
        case .custom: return "Comma-separated patterns"
        }
    }
}

enum SyncDirection: String, CaseIterable, Identifiable, Codable {
    case push
    case pull

    var id: String { rawValue }

    var label: String {
        switch self {
        case .push: return "Push (local → remote)"
        case .pull: return "Pull (remote → local)"
        }
    }
}

enum ScheduleType: String, CaseIterable, Identifiable, Codable {
    case interval
    case daily
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .interval: return "Every X minutes"
        case .daily: return "Daily at specific time"
        case .weekly: return "Weekly on specific days"
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct SyncSchedule: Codable, Equatable {
    var enabled: Bool
    var type: ScheduleType
    var intervalMinutes: Int // For interval type
    var dailyTime: Date // For daily type (only time component used)
    var weeklyDays: Set<Weekday> // For weekly type
    var weeklyTime: Date // For weekly type (only time component used)

    static var `default`: SyncSchedule {
        SyncSchedule(
            enabled: false,
            type: .interval,
            intervalMinutes: 30,
            dailyTime: Calendar.current.date(from: DateComponents(hour: 2, minute: 0)) ?? Date(),
            weeklyDays: [.monday, .friday],
            weeklyTime: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        )
    }
}


enum ConflictResolution: String, CaseIterable, Identifiable {
    case keepLocal = "keep_local"
    case keepRemote = "keep_remote"
    case keepNewer = "keep_newer"
    case keepLarger = "keep_larger"
    case skip = "skip"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepLocal: return "Keep Local"
        case .keepRemote: return "Keep Remote"
        case .keepNewer: return "Keep Newer"
        case .keepLarger: return "Keep Larger"
        case .skip: return "Skip"
        }
    }
}

struct FileConflict: Identifiable {
    let id = UUID()
    let path: String
    let localModified: Date?
    let remoteModified: Date?
    let localSize: Int64?
    let remoteSize: Int64?
    var resolution: ConflictResolution = .keepNewer
}

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

enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case success(String)
    case failed(String)
}

enum NetworkStatus: Equatable {
    case connected
    case disconnected
    case unknown

    var isConnected: Bool {
        self == .connected
    }

    var label: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .unknown: return "Unknown"
        }
    }
}

struct TransferEstimate {
    let fileCount: Int
    let totalBytes: Int64
    let estimatedSeconds: Int

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var formattedTime: String {
        if estimatedSeconds < 60 {
            return "\(estimatedSeconds)s"
        } else if estimatedSeconds < 3600 {
            let minutes = estimatedSeconds / 60
            let seconds = estimatedSeconds % 60
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            let hours = estimatedSeconds / 3600
            let minutes = (estimatedSeconds % 3600) / 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}

enum SyncError: LocalizedError, Equatable {
    case authenticationFailed
    case networkUnreachable(String)
    case permissionDenied(path: String)
    case diskFull
    case pathNotFound(path: String)
    case hostKeyChanged
    case rsyncNotFound
    case timeout
    case cancelled
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Check your username and password."
        case .networkUnreachable(let host):
            return "Cannot reach the remote host '\(host)'. Check your network connection."
        case .permissionDenied(let path):
            return "Permission denied for: \(path)"
        case .diskFull:
            return "Not enough disk space on the destination."
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .hostKeyChanged:
            return "Host key verification failed. The remote host's key has changed."
        case .rsyncNotFound:
            return "rsync command not found. Please install rsync."
        case .timeout:
            return "Connection timed out. The remote host is not responding."
        case .cancelled:
            return "Sync was cancelled."
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "Try using SSH keys instead of password, or verify your credentials are correct."
        case .networkUnreachable:
            return "Make sure you're connected to the network and the host is reachable. Try running 'Test Connection' first."
        case .permissionDenied:
            return "Check file permissions on the remote system. You may need to change ownership or permissions."
        case .diskFull:
            return "Free up space on the destination drive or choose a different destination."
        case .pathNotFound:
            return "Verify the path exists and is typed correctly. The path might have been moved or deleted."
        case .hostKeyChanged:
            return "Remove the old key from ~/.ssh/known_hosts or disable strict host key checking in settings."
        case .rsyncNotFound:
            return "Install rsync using Homebrew: brew install rsync"
        case .timeout:
            return "Check your network connection and try again. The remote server might be down or unreachable."
        case .cancelled:
            return nil
        case .unknown:
            return "Check the sync logs for more details. If the problem persists, report this issue."
        }
    }

    static func parse(from output: String) -> SyncError {
        let lowercased = output.lowercased()

        if lowercased.contains("command not found") && lowercased.contains("rsync") {
            return .rsyncNotFound
        } else if lowercased.contains("permission denied") {
            // Try to extract path from error
            if let pathMatch = output.range(of: #"([/~][^\s:]+)"#, options: .regularExpression) {
                let path = String(output[pathMatch])
                return .permissionDenied(path: path)
            }
            return .permissionDenied(path: "unknown")
        } else if lowercased.contains("no route to host") || lowercased.contains("connection refused") {
            // Extract host if possible
            if let hostMatch = output.range(of: #"@([^\s:]+)"#, options: .regularExpression) {
                let host = String(output[hostMatch]).replacingOccurrences(of: "@", with: "")
                return .networkUnreachable(host)
            }
            return .networkUnreachable("unknown")
        } else if lowercased.contains("authentication failed") || lowercased.contains("permission denied (publickey") || lowercased.contains("password:") {
            return .authenticationFailed
        } else if lowercased.contains("no space left on device") || lowercased.contains("disk quota exceeded") {
            return .diskFull
        } else if lowercased.contains("no such file or directory") {
            // Try to extract path
            if let pathMatch = output.range(of: #"([/~][^\s:]+)"#, options: .regularExpression) {
                let path = String(output[pathMatch])
                return .pathNotFound(path: path)
            }
            return .pathNotFound(path: "unknown")
        } else if lowercased.contains("host key") && (lowercased.contains("changed") || lowercased.contains("verification failed")) {
            return .hostKeyChanged
        } else if lowercased.contains("connection timed out") || lowercased.contains("operation timed out") {
            return .timeout
        }

        return .unknown(message: String(output.prefix(200)))
    }
}

enum PreflightCheckResult: Equatable {
    case pass
    case warning(String)
    case fail(String)

    var isPassing: Bool {
        if case .pass = self { return true }
        if case .warning = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .fail = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .pass: return nil
        case .warning(let msg): return msg
        case .fail(let msg): return msg
        }
    }
}

struct PreflightChecks {
    let localPathExists: PreflightCheckResult
    let diskSpace: PreflightCheckResult
    let networkConnection: PreflightCheckResult

    var canProceed: Bool {
        !localPathExists.isFailure && !diskSpace.isFailure && !networkConnection.isFailure
    }

    var hasWarnings: Bool {
        if case .warning = localPathExists { return true }
        if case .warning = diskSpace { return true }
        if case .warning = networkConnection { return true }
        return false
    }

    var allResults: [PreflightCheckResult] {
        [localPathExists, diskSpace, networkConnection]
    }
}

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var host = ""
    @Published var username = ""
    @Published var password = ""
    @Published var remotePath = ""
    @Published var localPath = ""
    @Published var syncDirection: SyncDirection = .push
    @Published var dryRun = false
    @Published var bandwidthLimitKBps: Int = 0
    @Published var resumePartials = false
    @Published var notifyOnCompletion = false
    @Published var selectedFilter: FileFilter = .all
    @Published var customFilterPatterns = ""
    @Published var excludePatterns = ""
    @Published var statusMessage = "Idle"
    @Published var isSyncing = false
    @Published var progress: Double? = nil
    @Published var log: [String] = []
    @Published var quietMode = false
    @Published var currentFile: String? = nil
    @Published var currentSpeed: String? = nil
    @Published var filesTransferred: Int = 0
    @Published var estimatedTotalFiles: Int = 0
    @Published var profiles: [SyncProfile] = []
    @Published var groups: [SyncGroup] = []
    @Published var schedule: SyncSchedule = .default {
        didSet {
            guard schedule != oldValue else { return }
            handleScheduleChange()
        }
    }
    // Legacy support - kept for migration
    @Published var autoSyncEnabled = false
    @Published var autoSyncIntervalMinutes = 30
    @Published var strictHostKeyChecking = false
    @Published var optimizeForSpeed = false
    @Published var deleteRemoteFiles = false
    @Published var history: [SyncHistoryEntry] = []
    @Published var conflicts: [FileConflict] = []
    @Published var showingConflictResolution = false
    @Published var isDetectingConflicts = false
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var transferEstimate: TransferEstimate? = nil
    @Published var isEstimating = false
    @Published var showingEstimate = false
    @Published var recentHosts: [String] = []
    @Published var recentLocalPaths: [String] = []
    @Published var preflightChecks: PreflightChecks? = nil
    @Published var showingPreflightResults = false
    @Published var isRunningPreflightChecks = false
    @Published var lastSyncError: SyncError? = nil
    @Published var showingSyncError = false
    @Published var autoRetryEnabled = true
    @Published var maxRetryAttempts = 3
    @Published var currentRetryAttempt = 0
    @Published var verifyAfterSync = false
    @Published var isVerifying = false
    @Published var verificationResult: String? = nil
    @Published var showingVerificationResult = false
    @Published var networkStatus: NetworkStatus = .unknown
    @Published var networkMonitoringEnabled = true
    @Published var pauseSyncOnNetworkLoss = true

    private let maxLogLines = 500
    private let maxHistoryEntries = 50
    private let historyFileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("OmniSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }()
    let logFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("omnisync.log")
    private var runner = RsyncRunner()
    private var autoSyncTimer: Timer?
    private var cancellationRequested = false
    private var lastProgressUpdate = Date.distantPast
    private var cancellables = Set<AnyCancellable>()
    private var currentLogBuffer: [String] = []
    private var currentSyncStart: Date?
    private var baselineProfile: SyncProfile?
    private var currentBytesTransferred: Int64 = 0
    private var currentPeakSpeed: Double = 0
    private var networkMonitor: NWPathMonitor?
    private var networkMonitorQueue = DispatchQueue(label: "com.omnisync.networkmonitor")

    deinit {
        autoSyncTimer?.invalidate()
        networkMonitor?.cancel()
    }

    init() {
        loadPersisted()
        history = Self.loadHistory(from: historyFileURL)
        baselineProfile = snapshotProfile(named: "Default")
        recentHosts = Self.loadRecentHosts()
        recentLocalPaths = Self.loadRecentPaths()
        setupPersistence()
        if schedule.enabled {
            handleScheduleChange()
        }
        if networkMonitoringEnabled {
            startNetworkMonitoring()
        }
    }

    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }

                let newStatus: NetworkStatus = path.status == .satisfied ? .connected : .disconnected

                // Only log and react if status changed
                if newStatus != self.networkStatus {
                    self.networkStatus = newStatus

                    if newStatus == .connected {
                        self.appendLogs(["Network connected"], progress: nil)
                    } else {
                        self.appendLogs(["Network disconnected"], progress: nil)

                        // Pause ongoing sync if enabled
                        if self.pauseSyncOnNetworkLoss && self.isSyncing {
                            self.appendLogs(["Pausing sync due to network loss..."], progress: nil)
                            self.cancelSync()
                        }
                    }
                }
            }
        }
        networkMonitor?.start(queue: networkMonitorQueue)
    }

    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
        networkStatus = .unknown
    }

    var canSync: Bool {
        !host.isEmpty && !username.isEmpty && !remotePath.isEmpty && !localPath.isEmpty && !isSyncing
    }

    func estimateTransfer() {
        guard canSync else { return }
        isEstimating = true
        transferEstimate = nil

        Task {
            let filterArgs = buildFilterArgs()
            let config = RsyncConfig(
                host: host,
                username: username,
                password: password,
                remotePath: remotePath,
                localPath: localPath,
                syncDirection: syncDirection,
                filterArgs: filterArgs,
                quietMode: true,
                logFileURL: logFileURL,
                strictHostKeyChecking: strictHostKeyChecking,
                dryRun: true,
                bandwidthLimitKBps: 0,
                resumePartials: false,
                optimizeForSpeed: optimizeForSpeed,
                deleteRemoteFiles: deleteRemoteFiles
            )

            var outputLines: [String] = []
            var fileCount = 0

            let estimateRunner = RsyncRunner()
            estimateRunner.run(
                config: config,
                onLog: { lines in
                    outputLines.append(contentsOf: lines)
                },
                onFile: { _ in
                    fileCount += 1
                },
                onSpeed: { _ in },
                onProgress: { _ in },
                onStart: { },
                onCompletion: { [weak self] success in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.isEstimating = false

                        if success {
                            // Parse rsync stats output
                            let totalBytes = self.parseTransferSize(from: outputLines)

                            // Estimate time based on typical speeds
                            // Assume 10 MB/s for LAN, 1 MB/s otherwise
                            let bytesPerSecond: Int64 = self.optimizeForSpeed ? 10_000_000 : 1_000_000
                            let estimatedSeconds = totalBytes > 0 ? Int(totalBytes / bytesPerSecond) : 0

                            self.transferEstimate = TransferEstimate(
                                fileCount: fileCount,
                                totalBytes: totalBytes,
                                estimatedSeconds: max(1, estimatedSeconds)
                            )
                            self.showingEstimate = true
                        }
                    }
                }
            )
        }
    }

    private func parseTransferSize(from lines: [String]) -> Int64 {
        // Look for "total size is X" line in rsync output
        for line in lines.reversed() {
            if line.contains("total size is") {
                let components = line.components(separatedBy: " ")
                if let index = components.firstIndex(where: { $0 == "is" }),
                   index + 1 < components.count {
                    let sizeString = components[index + 1].replacingOccurrences(of: ",", with: "")
                    if let size = Int64(sizeString) {
                        return size
                    }
                }
            }
        }
        return 0
    }

    private func parseBytesTransferred(from line: String) -> Int64? {
        // Parse "sent X bytes  received Y bytes" line
        if line.contains("sent") && line.contains("bytes") && line.contains("received") {
            // Extract sent and received bytes
            let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
            var sentBytes: Int64 = 0
            var receivedBytes: Int64 = 0

            for i in 0..<components.count {
                if components[i] == "sent" && i + 2 < components.count && components[i + 2] == "bytes" {
                    let bytesStr = components[i + 1].replacingOccurrences(of: ",", with: "")
                    sentBytes = Int64(bytesStr) ?? 0
                }
                if components[i] == "received" && i + 2 < components.count && components[i + 2] == "bytes" {
                    let bytesStr = components[i + 1].replacingOccurrences(of: ",", with: "")
                    receivedBytes = Int64(bytesStr) ?? 0
                }
            }

            if sentBytes > 0 || receivedBytes > 0 {
                return sentBytes + receivedBytes
            }
        }
        return nil
    }

    private func parseSpeedMBps(from speedString: String) -> Double? {
        // Parse speed like "10.5MB/s" or "1.2GB/s" or "500KB/s"
        let components = speedString.replacingOccurrences(of: "/s", with: "").uppercased()

        if components.contains("GB") {
            if let value = Double(components.replacingOccurrences(of: "GB", with: "")) {
                return value * 1024 // Convert GB/s to MB/s
            }
        } else if components.contains("MB") {
            if let value = Double(components.replacingOccurrences(of: "MB", with: "")) {
                return value
            }
        } else if components.contains("KB") {
            if let value = Double(components.replacingOccurrences(of: "KB", with: "")) {
                return value / 1024 // Convert KB/s to MB/s
            }
        }
        return nil
    }

    func sync() {
        if autoRetryEnabled {
            syncWithRetry()
        } else {
            performSync()
        }
    }

    func syncToMultipleDestinations(_ destinations: [RemoteDestination]) async {
        // Store original settings to restore after
        let originalHost = host
        let originalUsername = username
        let originalRemotePath = remotePath

        var successCount = 0
        for (index, destination) in destinations.enumerated() {
            // Update current destination
            await MainActor.run {
                host = destination.host
                username = destination.username
                remotePath = destination.remotePath
                statusMessage = "Syncing to destination \(index + 1) of \(destinations.count): \(destination.host)"
            }

            // Perform sync
            await withCheckedContinuation { continuation in
                var completionCalled = false
                performSync()

                // Wait for sync to complete by observing isSyncing
                Task { @MainActor in
                    while isSyncing {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    }
                    if !completionCalled {
                        completionCalled = true
                        continuation.resume()
                    }
                }
            }

            // Check if sync was successful
            if let lastEntry = history.first, lastEntry.success {
                successCount += 1
            }
        }

        // Restore original settings
        await MainActor.run {
            host = originalHost
            username = originalUsername
            remotePath = originalRemotePath
            statusMessage = "Completed syncing to \(successCount) of \(destinations.count) destinations"
        }
    }

    private func syncWithRetry() {
        currentRetryAttempt = 0
        attemptSync()
    }

    private func performSync() {
        attemptSync()
    }

    private func attemptSync() {
        guard canSync else { return }
        if isSyncing { return }
        guard FileManager.default.fileExists(atPath: localPath) else {
            statusMessage = "Local path not found"
            return
        }

        // Track recent items (only on first attempt)
        if currentRetryAttempt == 0 {
            addToRecentHosts(host)
            addToRecentPaths(localPath)
        }

        cancellationRequested = false
        log.removeAll()
        currentLogBuffer.removeAll()
        currentSyncStart = Date()
        currentBytesTransferred = 0
        currentPeakSpeed = 0
        statusMessage = "Starting sync..."
        isSyncing = true
        progress = 0
        currentFile = nil
        currentSpeed = nil
        filesTransferred = 0
        estimatedTotalFiles = 0
        resetLogFile()

        let filterArgs = buildFilterArgs()
        let config = RsyncConfig(
            host: host,
            username: username,
            password: password,
            remotePath: remotePath,
            localPath: localPath,
            syncDirection: syncDirection,
            filterArgs: filterArgs,
            quietMode: quietMode,
            logFileURL: logFileURL,
            strictHostKeyChecking: strictHostKeyChecking,
            dryRun: dryRun,
            bandwidthLimitKBps: bandwidthLimitKBps,
            resumePartials: resumePartials,
            optimizeForSpeed: optimizeForSpeed,
            deleteRemoteFiles: deleteRemoteFiles
        )

        runner.run(
            config: config,
            onLog: { [weak self] lines in
                Task { @MainActor in
                    self?.appendLogs(lines, progress: nil)
                    // Parse bandwidth stats from logs
                    for line in lines {
                        if let bytes = self?.parseBytesTransferred(from: line) {
                            self?.currentBytesTransferred = bytes
                        }
                    }
                }
            },
            onFile: { [weak self] file in
                Task { @MainActor in
                    self?.currentFile = file
                    if let self = self {
                        self.filesTransferred += 1
                    }
                    self?.updateStatus()
                }
            },
            onSpeed: { [weak self] speed in
                Task { @MainActor in
                    self?.currentSpeed = speed
                    // Track peak speed for statistics
                    if let speedMBps = self?.parseSpeedMBps(from: speed) {
                        self?.currentPeakSpeed = max(self?.currentPeakSpeed ?? 0, speedMBps)
                    }
                    self?.updateStatus()
                }
            },
            onProgress: { [weak self] value in
                Task { @MainActor in self?.appendLogs([], progress: value) }
            },
            onStart: { [weak self] in
                Task { @MainActor in self?.appendLogs(["Launching rsync to \(config.host)"], progress: nil) }
            },
            onCompletion: { [weak self] success in
                Task { @MainActor in
                    guard let self else { return }
                    if self.cancellationRequested {
                        self.statusMessage = "Sync cancelled"
                        self.isSyncing = false
                        self.progress = nil
                        self.currentFile = nil
                        self.currentSpeed = nil
                        self.cancellationRequested = false
                        self.recordHistory(success: success)
                        self.notifyIfNeeded(success: success)
                    } else {
                        if success {
                            self.statusMessage = "Sync completed"
                            self.lastSyncError = nil
                            self.currentRetryAttempt = 0
                            self.isSyncing = false
                            self.progress = nil
                            self.currentFile = nil
                            self.currentSpeed = nil
                            self.cancellationRequested = false
                            self.recordHistory(success: success)
                            self.notifyIfNeeded(success: success)

                            // Run verification if enabled
                            if self.verifyAfterSync {
                                self.verifySync()
                            }
                        } else {
                            // Parse error from log
                            let errorLog = self.log.joined(separator: "\n")
                            self.lastSyncError = SyncError.parse(from: errorLog)

                            // Check if we should retry
                            if self.autoRetryEnabled && self.currentRetryAttempt < self.maxRetryAttempts {
                                self.currentRetryAttempt += 1
                                let delay = pow(2.0, Double(self.currentRetryAttempt)) // 2s, 4s, 8s
                                self.statusMessage = "Sync failed - retrying in \(Int(delay))s (attempt \(self.currentRetryAttempt)/\(self.maxRetryAttempts))"
                                self.appendLogs(["Retrying sync (attempt \(self.currentRetryAttempt)/\(self.maxRetryAttempts)) after \(Int(delay))s..."], progress: nil)

                                // Reset sync state but keep retry counter
                                self.isSyncing = false
                                self.progress = nil
                                self.currentFile = nil
                                self.currentSpeed = nil

                                // Schedule retry after delay
                                Task {
                                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                    await MainActor.run {
                                        self.attemptSync()
                                    }
                                }
                            } else {
                                // No more retries or retry disabled
                                if self.autoRetryEnabled && self.currentRetryAttempt >= self.maxRetryAttempts {
                                    self.statusMessage = "Sync failed after \(self.maxRetryAttempts) attempts"
                                    self.appendLogs(["Sync failed after \(self.maxRetryAttempts) retry attempts"], progress: nil)
                                } else {
                                    self.statusMessage = "Sync failed"
                                }
                                self.showingSyncError = true
                                self.currentRetryAttempt = 0
                                self.isSyncing = false
                                self.progress = nil
                                self.currentFile = nil
                                self.currentSpeed = nil
                                self.cancellationRequested = false
                                self.recordHistory(success: success)
                                self.notifyIfNeeded(success: success)
                            }
                        }
                    }
                }
            }
        )
    }

    func cancelSync() {
        cancellationRequested = true
        runner.cancel()
        isSyncing = false
        statusMessage = "Sync cancelled"
        progress = nil
        currentFile = nil
        currentSpeed = nil
    }

    func verifySync() {
        isVerifying = true
        statusMessage = "Verifying sync..."
        appendLogs(["Running verification with checksums..."], progress: nil)

        let filterArgs = buildFilterArgs()
        let config = RsyncConfig(
            host: host,
            username: username,
            password: password,
            remotePath: remotePath,
            localPath: localPath,
            syncDirection: syncDirection,
            filterArgs: filterArgs,
            quietMode: true,
            logFileURL: logFileURL,
            strictHostKeyChecking: strictHostKeyChecking,
            dryRun: true, // Dry run with checksum to verify
            bandwidthLimitKBps: 0,
            resumePartials: false,
            optimizeForSpeed: false, // Use checksum, not just size/time
            deleteRemoteFiles: false
        )

        var differences: [String] = []

        let verifyRunner = RsyncRunner()
        verifyRunner.run(
            config: config,
            onLog: { lines in
                // Capture any differences reported
                differences.append(contentsOf: lines.filter { !$0.isEmpty })
            },
            onFile: { file in
                // Files that would be transferred indicate differences
                differences.append("Difference detected: \(file)")
            },
            onSpeed: { _ in },
            onProgress: { _ in },
            onStart: { },
            onCompletion: { [weak self] success in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isVerifying = false

                    if success && differences.isEmpty {
                        self.verificationResult = "✓ Verification passed - all files match"
                        self.statusMessage = "Sync completed and verified"
                        self.appendLogs(["Verification complete: All files verified successfully"], progress: nil)
                    } else if success && !differences.isEmpty {
                        self.verificationResult = "⚠ Verification found \(differences.count) difference(s)"
                        self.appendLogs(["Verification found differences:"] + differences.prefix(10).map { "  • \($0)" }, progress: nil)
                    } else {
                        self.verificationResult = "✗ Verification failed to complete"
                        self.appendLogs(["Verification failed to complete"], progress: nil)
                    }
                    self.showingVerificationResult = true
                }
            }
        )
    }

    func updateAutoSyncEnabled(_ enabled: Bool) {
        schedule.enabled = enabled
    }

    func refreshAutoSyncTimerIfNeeded() {
        guard schedule.enabled else { return }
        guard ensureAutoSyncReady() else { return }
        startAutoSyncTimer()
    }

    private func handleScheduleChange() {
        guard schedule.enabled else {
            stopAutoSyncTimer()
            return
        }
        guard ensureAutoSyncReady() else { return }
        startAutoSyncTimer()
    }

    private func calculateNextRunDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch schedule.type {
        case .interval:
            return calendar.date(byAdding: .minute, value: schedule.intervalMinutes, to: now)

        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: schedule.dailyTime)
            guard let hour = components.hour, let minute = components.minute else { return nil }

            var nextRun = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            if nextRun <= now {
                nextRun = calendar.date(byAdding: .day, value: 1, to: nextRun) ?? now
            }
            return nextRun

        case .weekly:
            guard !schedule.weeklyDays.isEmpty else { return nil }

            let components = calendar.dateComponents([.hour, .minute], from: schedule.weeklyTime)
            guard let hour = components.hour, let minute = components.minute else { return nil }

            let currentWeekday = calendar.component(.weekday, from: now)
            let sortedDays = schedule.weeklyDays.map { $0.rawValue }.sorted()

            // Find next scheduled day
            var nextDay: Int?
            for day in sortedDays {
                if day > currentWeekday {
                    nextDay = day
                    break
                } else if day == currentWeekday {
                    // Check if time hasn't passed yet today
                    if let todayRun = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now),
                       todayRun > now {
                        nextDay = day
                        break
                    }
                }
            }

            // If no day found this week, use first day of next week
            if nextDay == nil {
                nextDay = sortedDays.first
            }

            guard let targetWeekday = nextDay else { return nil }

            // Calculate days to add
            var daysToAdd = targetWeekday - currentWeekday
            if daysToAdd <= 0 {
                daysToAdd += 7
            }

            var nextRun = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
            nextRun = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: nextRun) ?? nextRun

            return nextRun
        }
    }

    func testConnection() {
        guard !host.isEmpty && !username.isEmpty else {
            connectionStatus = .failed("Please enter host and username")
            return
        }

        connectionStatus = .testing

        Task.detached { [weak self] in
            guard let self = self else { return }

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

            var sshArgs = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=\(await self.strictHostKeyChecking ? "yes" : "accept-new")"
            ]

            let currentPassword = await self.password
            let currentHost = await self.host
            let currentUsername = await self.username

            if !currentPassword.isEmpty {
                // Try to find sshpass
                let candidates = [
                    "/usr/bin/sshpass",
                    "/opt/homebrew/bin/sshpass",
                    "/usr/local/bin/sshpass"
                ]

                if let sshPassPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                    process.executableURL = URL(fileURLWithPath: sshPassPath)
                    sshArgs = ["-p", currentPassword, "ssh"] + sshArgs + ["\(currentUsername)@\(currentHost)", "echo", "OK"]
                } else {
                    sshArgs.append(contentsOf: ["\(currentUsername)@\(currentHost)", "echo", "OK"])
                }
            } else {
                sshArgs.append(contentsOf: ["\(currentUsername)@\(currentHost)", "echo", "OK"])
            }

            process.arguments = sshArgs

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    if process.terminationStatus == 0 {
                        self.connectionStatus = .success("Connection successful!")
                    } else {
                        let message = errorOutput.isEmpty ? "Connection failed (exit code: \(process.terminationStatus))" : String(errorOutput.prefix(100))
                        self.connectionStatus = .failed(message)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.connectionStatus = .failed("Failed to run SSH: \(error.localizedDescription)")
                }
            }
        }
    }

    func detectConflicts() {
        isDetectingConflicts = true
        conflicts.removeAll()

        Task {
            let filterArgs = buildFilterArgs()
            let config = RsyncConfig(
                host: host,
                username: username,
                password: password,
                remotePath: remotePath,
                localPath: localPath,
                syncDirection: syncDirection,
                filterArgs: filterArgs,
                quietMode: false,
                logFileURL: logFileURL,
                strictHostKeyChecking: strictHostKeyChecking,
                dryRun: true, // Force dry-run for conflict detection
                bandwidthLimitKBps: 0,
                resumePartials: false,
                optimizeForSpeed: optimizeForSpeed,
                deleteRemoteFiles: deleteRemoteFiles
            )

            var detectedConflicts: [FileConflict] = []

            runner.run(
                config: config,
                onLog: { lines in
                    // Parse rsync itemize output for conflicts
                    for line in lines {
                        if let conflict = self.parseConflictFromItemize(line) {
                            detectedConflicts.append(conflict)
                        }
                    }
                },
                onFile: { _ in },
                onSpeed: { _ in },
                onProgress: { _ in },
                onStart: { },
                onCompletion: { [weak self] success in
                    Task { @MainActor in
                        guard let self else { return }
                        self.conflicts = detectedConflicts
                        self.isDetectingConflicts = false
                        if !detectedConflicts.isEmpty {
                            self.showingConflictResolution = true
                        } else if success {
                            // No conflicts, proceed with sync
                            self.sync()
                        }
                    }
                }
            )
        }
    }

    private func parseConflictFromItemize(_ line: String) -> FileConflict? {
        // Rsync itemize format: YXcstpoguax path
        // Where Y is the type of update (e.g., '>' for transferred file)
        // We're looking for files that would be overwritten
        guard line.count > 11 else { return nil }

        let updateType = line.prefix(1)
        let filePath = String(line.dropFirst(12))

        // Only care about files that would be modified
        if updateType == ">" || updateType == "." || updateType == "c" {
            return FileConflict(
                path: filePath,
                localModified: nil,
                remoteModified: nil,
                localSize: nil,
                remoteSize: nil,
                resolution: .keepNewer
            )
        }

        return nil
    }

    func runPreflightChecks() {
        isRunningPreflightChecks = true

        Task {
            // Check 1: Local path exists
            let localPathResult: PreflightCheckResult
            if localPath.isEmpty {
                localPathResult = .fail("Local path is empty")
            } else {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        localPathResult = .pass
                    } else {
                        localPathResult = .fail("Local path is not a directory")
                    }
                } else {
                    localPathResult = .fail("Local path does not exist")
                }
            }

            // Check 2: Disk space
            let diskSpaceResult: PreflightCheckResult
            if case .pass = localPathResult {
                do {
                    let url = URL(fileURLWithPath: localPath)
                    let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                    if let available = values.volumeAvailableCapacity {
                        let oneGB: Int64 = 1_000_000_000
                        if available < oneGB {
                            let formatter = ByteCountFormatter()
                            formatter.countStyle = .file
                            let freeSpace = formatter.string(fromByteCount: Int64(available))
                            diskSpaceResult = .warning("Less than 1GB free space (\(freeSpace) available)")
                        } else {
                            diskSpaceResult = .pass
                        }
                    } else {
                        diskSpaceResult = .warning("Could not determine available disk space")
                    }
                } catch {
                    diskSpaceResult = .warning("Could not check disk space: \(error.localizedDescription)")
                }
            } else {
                diskSpaceResult = .warning("Skipped (local path check failed)")
            }

            // Check 3: Network connection
            let networkResult: PreflightCheckResult
            if host.isEmpty || username.isEmpty {
                networkResult = .warning("Host or username not configured")
            } else {
                // Quick test using existing connection status if available
                if case .success = connectionStatus {
                    networkResult = .pass
                } else {
                    // Run a quick test
                    await testConnectionForPreflight()
                    // Give it a moment to complete
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                    switch connectionStatus {
                    case .success:
                        networkResult = .pass
                    case .failed(let message):
                        networkResult = .fail("Connection test failed: \(message)")
                    case .testing:
                        networkResult = .warning("Connection test still running")
                    case .unknown:
                        networkResult = .warning("Connection not tested")
                    }
                }
            }

            await MainActor.run {
                self.preflightChecks = PreflightChecks(
                    localPathExists: localPathResult,
                    diskSpace: diskSpaceResult,
                    networkConnection: networkResult
                )
                self.isRunningPreflightChecks = false
                self.showingPreflightResults = true
            }
        }
    }

    private func testConnectionForPreflight() async {
        // Use the existing testConnection but wait for it
        testConnection()
    }

    private func sshpassCandidatePaths() -> [String] {
        var candidates = [
            "/usr/bin/sshpass",
            "/opt/homebrew/bin/sshpass",
            "/usr/local/bin/sshpass"
        ]
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let extra = pathEnv.split(separator: ":").map { "\($0)/sshpass" }
            candidates.append(contentsOf: extra)
        }
        return Array(Set(candidates))
    }

    // MARK: - Internal helpers

    @MainActor
    private func appendLogs(_ lines: [String], progress latestProgress: Double?) {
        guard !lines.isEmpty || latestProgress != nil else { return }
        if !lines.isEmpty {
            if !quietMode {
                log.append(contentsOf: lines)
                if log.count > maxLogLines {
                    log.removeFirst(log.count - maxLogLines)
                }
            }
            currentLogBuffer.append(contentsOf: lines)
        }
        if let latestProgress {
            let now = Date()
            let delta = abs((progress ?? 0) - latestProgress)
            if delta >= 0.02 || now.timeIntervalSince(lastProgressUpdate) >= 0.5 {
                progress = latestProgress
                lastProgressUpdate = now
                updateStatus()
            }
        }
    }

    private func updateStatus() {
        let pctText: String? = {
            guard let pct = progress else { return nil }
            return "\(Int(pct * 100))%"
        }()
        let speedText = currentSpeed

        if let file = currentFile {
            var parts: [String] = ["Syncing \(file)"]
            if let pctText {
                parts.append("(\(pctText))")
            }
            if let speedText {
                parts.append("@ \(speedText)")
            }
            statusMessage = parts.joined(separator: " ")
        } else if let pctText {
            statusMessage = "Syncing (\(pctText))"
        } else {
            statusMessage = "Syncing..."
        }
    }

    private func startAutoSyncTimer() {
        stopAutoSyncTimer()

        guard let nextRun = calculateNextRunDate() else {
            appendLogs(["Failed to calculate next sync time"], progress: nil)
            return
        }

        let interval = nextRun.timeIntervalSinceNow
        guard interval > 0 else {
            // Next run is now or in the past, run immediately and reschedule
            Task { @MainActor in
                if self.isSyncing {
                    self.appendLogs(["Scheduled sync skipped; a sync is already running."], progress: nil)
                } else {
                    self.sync()
                }
                // Reschedule for next run
                self.startAutoSyncTimer()
            }
            return
        }

        // Log next scheduled run
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        appendLogs(["Next scheduled sync: \(formatter.string(from: nextRun))"], progress: nil)

        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.ensureAutoSyncReady() else { return }
                if self.isSyncing {
                    self.appendLogs(["Scheduled sync skipped; a sync is already running."], progress: nil)
                } else {
                    self.sync()
                }
                // Reschedule for next occurrence
                self.startAutoSyncTimer()
            }
        }
    }

    private func stopAutoSyncTimer() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    private func ensureAutoSyncReady() -> Bool {
        guard canSync else {
            appendLogs(["Fill in connection and paths before enabling auto sync."], progress: nil)
            autoSyncEnabled = false
            return false
        }
        return true
    }

    private func handleAutoSyncToggle() {
        // Legacy support - migrate to new schedule system
        schedule.enabled = autoSyncEnabled
        schedule.intervalMinutes = autoSyncIntervalMinutes
    }

    private func buildFilterArgs() -> [String] {
        var args: [String] = []

        // Exclusions first
        if !excludePatterns.isEmpty {
            let excludes = excludePatterns
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            args += excludes.map { "--exclude=\($0)" }
        }

        // Then inclusions
        let filter = selectedFilter
        if filter == .all {
            return args // Return only exclusions if any, or empty array
        }

        var patterns = filter.patterns

        if filter == .custom {
            let custom = customFilterPatterns
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { pattern -> String in
                    pattern.hasPrefix("--include=") ? String(pattern.dropFirst("--include=".count)) : pattern
                }
            patterns.append(contentsOf: custom)
        }

        guard !patterns.isEmpty else { return args }
        return args + ["--include=*/"] + patterns.map { "--include=\($0)" } + ["--exclude=*"]
    }

    private func resetLogFile() {
        try? FileManager.default.removeItem(at: logFileURL)
        FileManager.default.createFile(atPath: logFileURL.path, contents: Data(), attributes: [.posixPermissions: 0o600])
    }

    private func setupPersistence() {
        let defaults = UserDefaults.standard

        func bind<T>(_ publisher: Published<T>.Publisher, key: String) {
            publisher
                .sink { value in
                    defaults.set(value, forKey: key)
                }
                .store(in: &cancellables)
        }

        bind($host, key: "host")
        bind($username, key: "username")
        bind($remotePath, key: "remotePath")
        bind($localPath, key: "localPath")
        bind($customFilterPatterns, key: "customFilterPatterns")
        bind($quietMode, key: "quietMode")
        bind($autoSyncEnabled, key: "autoSyncEnabled")
        bind($autoSyncIntervalMinutes, key: "autoSyncIntervalMinutes")
        bind($strictHostKeyChecking, key: "strictHostKeyChecking")
        bind($dryRun, key: "dryRun")
        bind($bandwidthLimitKBps, key: "bandwidthLimitKBps")
        bind($resumePartials, key: "resumePartials")
        bind($optimizeForSpeed, key: "optimizeForSpeed")
        bind($deleteRemoteFiles, key: "deleteRemoteFiles")
        bind($networkMonitoringEnabled, key: "networkMonitoringEnabled")
        bind($pauseSyncOnNetworkLoss, key: "pauseSyncOnNetworkLoss")

        $syncDirection
            .sink { direction in
                defaults.set(direction.rawValue, forKey: "syncDirection")
            }
            .store(in: &cancellables)

        $password
            .sink { [weak self] value in
                self?.storePasswordInKeychain(value)
            }
            .store(in: &cancellables)

        $selectedFilter
            .sink { filter in
                defaults.set(filter.rawValue, forKey: "selectedFilter")
            }
            .store(in: &cancellables)

        $notifyOnCompletion
            .sink { [weak self] enabled in
                defaults.set(enabled, forKey: "notifyOnCompletion")
                if enabled {
                    self?.requestNotificationPermission()
                }
            }
            .store(in: &cancellables)

        $profiles
            .sink { profiles in
                Self.persistProfiles(profiles)
            }
            .store(in: &cancellables)

        $groups
            .sink { groups in
                Self.persistGroups(groups)
            }
            .store(in: &cancellables)

        $schedule
            .sink { schedule in
                Self.persistSchedule(schedule)
            }
            .store(in: &cancellables)

        $networkMonitoringEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.startNetworkMonitoring()
                } else {
                    self?.stopNetworkMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    private func loadPersisted() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "host") ?? ""
        username = defaults.string(forKey: "username") ?? ""
        password = (try? readPasswordFromKeychain()) ?? ""
        remotePath = defaults.string(forKey: "remotePath") ?? ""
        localPath = defaults.string(forKey: "localPath") ?? ""
        customFilterPatterns = defaults.string(forKey: "customFilterPatterns") ?? ""
        quietMode = defaults.object(forKey: "quietMode") as? Bool ?? false
        autoSyncEnabled = defaults.object(forKey: "autoSyncEnabled") as? Bool ?? false
        autoSyncIntervalMinutes = defaults.object(forKey: "autoSyncIntervalMinutes") as? Int ?? 30
        strictHostKeyChecking = defaults.object(forKey: "strictHostKeyChecking") as? Bool ?? false
        dryRun = defaults.object(forKey: "dryRun") as? Bool ?? false
        bandwidthLimitKBps = defaults.object(forKey: "bandwidthLimitKBps") as? Int ?? 0
        resumePartials = defaults.object(forKey: "resumePartials") as? Bool ?? false
        notifyOnCompletion = defaults.object(forKey: "notifyOnCompletion") as? Bool ?? false
        optimizeForSpeed = defaults.object(forKey: "optimizeForSpeed") as? Bool ?? false
        deleteRemoteFiles = defaults.object(forKey: "deleteRemoteFiles") as? Bool ?? false
        networkMonitoringEnabled = defaults.object(forKey: "networkMonitoringEnabled") as? Bool ?? true
        pauseSyncOnNetworkLoss = defaults.object(forKey: "pauseSyncOnNetworkLoss") as? Bool ?? true
        if let filterRaw = defaults.string(forKey: "selectedFilter"), let filter = FileFilter(rawValue: filterRaw) {
            selectedFilter = filter
        }
        if let directionRaw = defaults.string(forKey: "syncDirection"), let direction = SyncDirection(rawValue: directionRaw) {
            syncDirection = direction
        }
        profiles = Self.loadProfiles()
        groups = Self.loadGroups()
        schedule = Self.loadSchedule()

        // Migrate legacy settings to new schedule if needed
        if schedule.type == .interval && schedule.intervalMinutes == 30 && (autoSyncEnabled || autoSyncIntervalMinutes != 30) {
            schedule.enabled = autoSyncEnabled
            schedule.intervalMinutes = autoSyncIntervalMinutes
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyIfNeeded(success: Bool) {
        guard notifyOnCompletion else { return }
        let content = UNMutableNotificationContent()
        content.title = "OmniSync"
        content.body = success ? "Sync completed successfully." : "Sync failed or was cancelled."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Profiles

    func saveCurrentProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = snapshotProfile(named: trimmed)
        profiles.append(profile)
    }

    func applyProfile(_ profile: SyncProfile) {
        host = profile.host
        username = profile.username
        remotePath = profile.remotePath
        localPath = profile.localPath
        if let filter = FileFilter(rawValue: profile.filter) {
            selectedFilter = filter
        }
        customFilterPatterns = profile.customFilterPatterns
        optimizeForSpeed = profile.optimizeForSpeed
        deleteRemoteFiles = profile.deleteRemote
    }

    func deleteProfile(_ profile: SyncProfile) {
        profiles.removeAll { $0.id == profile.id }
    }

    // MARK: - Groups

    func createGroup(named name: String, profileIDs: [UUID]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let group = SyncGroup(name: trimmed, profileIDs: profileIDs)
        groups.append(group)
    }

    func deleteGroup(_ group: SyncGroup) {
        groups.removeAll { $0.id == group.id }
    }

    func syncGroup(_ group: SyncGroup) async {
        for profileID in group.profileIDs {
            guard let profile = profiles.first(where: { $0.id == profileID }) else { continue }
            await MainActor.run {
                applyProfile(profile)
            }
            await sync()
        }
    }

    private static func persistProfiles(_ profiles: [SyncProfile]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profiles) {
            UserDefaults.standard.set(data, forKey: "syncProfiles")
        }
    }

    private static func loadProfiles() -> [SyncProfile] {
        guard let data = UserDefaults.standard.data(forKey: "syncProfiles") else { return [] }
        return (try? JSONDecoder().decode([SyncProfile].self, from: data)) ?? []
    }

    private static func persistGroups(_ groups: [SyncGroup]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(groups) {
            UserDefaults.standard.set(data, forKey: "syncGroups")
        }
    }

    private static func loadGroups() -> [SyncGroup] {
        guard let data = UserDefaults.standard.data(forKey: "syncGroups") else { return [] }
        return (try? JSONDecoder().decode([SyncGroup].self, from: data)) ?? []
    }

    private static func persistSchedule(_ schedule: SyncSchedule) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(schedule) {
            UserDefaults.standard.set(data, forKey: "syncSchedule")
        }
    }

    private static func loadSchedule() -> SyncSchedule {
        guard let data = UserDefaults.standard.data(forKey: "syncSchedule") else {
            return .default
        }
        return (try? JSONDecoder().decode(SyncSchedule.self, from: data)) ?? .default
    }

    func applyBaselineProfile() {
        guard let baseline = baselineProfile else { return }
        applyProfile(baseline)
    }

    private func snapshotProfile(named name: String) -> SyncProfile {
        SyncProfile(
            id: UUID(),
            name: name,
            host: host,
            username: username,
            remotePath: remotePath,
            localPath: localPath,
            filter: selectedFilter.rawValue,
            customFilterPatterns: customFilterPatterns,
            optimizeForSpeed: optimizeForSpeed,
            deleteRemote: deleteRemoteFiles
        )
    }

    private func recordHistory(success: Bool) {
        guard let start = currentSyncStart else { return }
        let endTime = Date()
        let duration = endTime.timeIntervalSince(start)

        // Calculate average speed in MB/s
        let averageSpeedMBps: Double
        if duration > 0 && currentBytesTransferred > 0 {
            let bytesPerSecond = Double(currentBytesTransferred) / duration
            averageSpeedMBps = bytesPerSecond / (1024 * 1024) // Convert to MB/s
        } else {
            averageSpeedMBps = 0
        }

        let entry = SyncHistoryEntry(
            id: UUID(),
            startedAt: start,
            endedAt: endTime,
            success: success && !cancellationRequested,
            direction: syncDirection,
            remotePath: remotePath,
            localPath: localPath,
            filter: selectedFilter.rawValue,
            customFilterPatterns: customFilterPatterns,
            logLines: currentLogBuffer,
            bytesTransferred: currentBytesTransferred,
            averageSpeedMBps: averageSpeedMBps
        )
        var updated = history
        updated.insert(entry, at: 0)
        if updated.count > maxHistoryEntries {
            updated = Array(updated.prefix(maxHistoryEntries))
        }
        history = updated
        Self.persistHistory(updated, to: historyFileURL)
        currentLogBuffer.removeAll()
        currentSyncStart = nil
        currentBytesTransferred = 0
        currentPeakSpeed = 0
    }

    private static func persistHistory(_ history: [SyncHistoryEntry], to url: URL) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadHistory(from url: URL) -> [SyncHistoryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SyncHistoryEntry].self, from: data)) ?? []
    }

    func exportHistory(format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "omnisync-history.\(format.fileExtension)"
        panel.canCreateDirectories = true
        panel.title = "Export Sync History"
        panel.message = "Choose where to save the exported history"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                do {
                    switch format {
                    case .csv:
                        let csv = self.generateCSV()
                        try csv.write(to: url, atomically: true, encoding: .utf8)
                    case .json:
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        encoder.dateEncodingStrategy = .iso8601
                        let data = try encoder.encode(self.history)
                        try data.write(to: url)
                    }
                    self.statusMessage = "History exported successfully"
                    self.appendLogs(["Exported \(self.history.count) history entries to \(url.lastPathComponent)"], progress: nil)
                } catch {
                    self.statusMessage = "Export failed: \(error.localizedDescription)"
                    self.appendLogs(["Failed to export history: \(error.localizedDescription)"], progress: nil)
                }
            }
        }
    }

    private func generateCSV() -> String {
        var csv = "Date,Time,Status,Direction,Local Path,Remote Path,Filter,Duration,Bytes Transferred,Avg Speed (MB/s)\n"

        for entry in history {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .none
            let date = dateFormatter.string(from: entry.startedAt)

            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            let time = timeFormatter.string(from: entry.startedAt)

            let status = entry.success ? "Success" : "Failed"
            let duration = entry.endedAt.timeIntervalSince(entry.startedAt)
            let durationStr = String(format: "%.1fs", duration)

            // Format bandwidth stats
            let bytesStr = ByteCountFormatter.string(fromByteCount: entry.bytesTransferred, countStyle: .file)
            let speedStr = String(format: "%.2f", entry.averageSpeedMBps)

            // Escape commas and quotes in fields
            let localPath = escapeCSV(entry.localPath)
            let remotePath = escapeCSV(entry.remotePath)
            let filter = escapeCSV(entry.filter)

            csv += "\(date),\(time),\(status),\(entry.direction.label),\(localPath),\(remotePath),\(filter),\(durationStr),\(bytesStr),\(speedStr)\n"
        }

        return csv
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    // MARK: - Keychain

    private func storePasswordInKeychain(_ password: String) {
        let account = "omnisync.password"
        let service = "com.omnisync.app"

        if password.isEmpty {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
                kSecAttrService as String: service
            ]
            SecItemDelete(query as CFDictionary)
            return
        }

        let encoded = password.data(using: .utf8) ?? Data()
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        let update: [String: Any] = [kSecValueData as String: encoded]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = encoded
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private func readPasswordFromKeychain() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "omnisync.password",
            kSecAttrService as String: "com.omnisync.app",
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return "" }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        guard let data = item as? Data, let password = String(data: data, encoding: .utf8) else { return "" }
        return password
    }

    // MARK: - Recent Items

    private func addToRecentHosts(_ host: String) {
        guard !host.isEmpty else { return }
        var recent = recentHosts
        recent.removeAll { $0 == host }
        recent.insert(host, at: 0)
        recentHosts = Array(recent.prefix(5))
        Self.saveRecentHosts(recentHosts)
    }

    private func addToRecentPaths(_ path: String) {
        guard !path.isEmpty else { return }
        var recent = recentLocalPaths
        recent.removeAll { $0 == path }
        recent.insert(path, at: 0)
        recentLocalPaths = Array(recent.prefix(5))
        Self.saveRecentPaths(recentLocalPaths)
    }

    private static func loadRecentHosts() -> [String] {
        UserDefaults.standard.stringArray(forKey: "recentHosts") ?? []
    }

    private static func saveRecentHosts(_ hosts: [String]) {
        UserDefaults.standard.set(hosts, forKey: "recentHosts")
    }

    private static func loadRecentPaths() -> [String] {
        UserDefaults.standard.stringArray(forKey: "recentLocalPaths") ?? []
    }

    private static func saveRecentPaths(_ paths: [String]) {
        UserDefaults.standard.set(paths, forKey: "recentLocalPaths")
    }
}

// MARK: - Rsync Runner

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

final class RsyncRunner {
    private var process: Process?
    private let tempKnownHosts = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("omnisync_known_hosts")
    private let queue = DispatchQueue(label: "rsync-output-buffer", qos: .utility)

    private func tearDownHandlers(for proc: Process) {
        if let out = proc.standardOutput as? Pipe {
            out.fileHandleForReading.readabilityHandler = nil
        }
        if let err = proc.standardError as? Pipe {
            err.fileHandleForReading.readabilityHandler = nil
        }
        proc.terminationHandler = nil
    }

    func run(
        config: RsyncConfig,
        onLog: @escaping ([String]) -> Void,
        onFile: @escaping (String) -> Void,
        onSpeed: @escaping (String) -> Void,
        onProgress: @escaping (Double?) -> Void,
        onStart: @escaping () -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) {
        if let current = process {
            if current.isRunning {
                onLog(["A sync is already running."])
                return
            } else {
                tearDownHandlers(for: current)
                process = nil
            }
        }
        prepareKnownHosts()
        resetLogFile(at: config.logFileURL)

        var sshOptions = [
            "-o", "StrictHostKeyChecking=\(config.strictHostKeyChecking ? "yes" : "accept-new")",
            "-o", "UserKnownHostsFile=\(tempKnownHosts.path)"
        ]
        if config.optimizeForSpeed {
            sshOptions += [
                "-o", "Compression=no",
                "-c", "aes128-gcm@openssh.com"
            ]
        }
        if config.password.isEmpty {
            sshOptions += ["-o", "BatchMode=yes"]
        }
        let sshCommand = (["ssh"] + sshOptions).joined(separator: " ")
        var rsyncArgs = ["-av", "--progress", "-e", sshCommand]
        if config.optimizeForSpeed {
            rsyncArgs.append("--whole-file")
        } else {
            rsyncArgs.append("-z")
        }
        if config.dryRun {
            rsyncArgs.append("--dry-run")
        }
        if config.resumePartials {
            rsyncArgs.append(contentsOf: ["--partial", "--append-verify"])
        }
        if config.deleteRemoteFiles {
            rsyncArgs.append("--delete")
        }
        if config.bandwidthLimitKBps > 0 {
            rsyncArgs.append("--bwlimit=\(config.bandwidthLimitKBps)")
        }
        rsyncArgs += config.filterArgs
        let (source, destination) = Self.buildPaths(from: config)
        rsyncArgs.append(contentsOf: [source, destination])

        var command: [String] = []
        let sshPassPath = sshpassCandidatePaths().first { FileManager.default.isExecutableFile(atPath: $0) }
        if !config.password.isEmpty, let sshPassPath {
            onLog(["Using sshpass at \(sshPassPath)"])
            command = [sshPassPath, "-p", config.password, "rsync"] + rsyncArgs
        } else {
            command = ["rsync"] + rsyncArgs
            if !config.password.isEmpty && sshPassPath == nil {
                onLog(["sshpass not found in common paths; falling back to key/agent auth."])
            }
        }

        onStart()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        var env = ProcessInfo.processInfo.environment
        let defaultPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(defaultPath):/opt/homebrew/bin:/usr/local/bin"
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let handler: (Pipe) -> Void = { [weak self] pipe in
            var pendingRemainder = ""
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                guard let self else { return }
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                FileHandle.standardOutput.write(data)

                queue.async {
                    let text = String(decoding: data, as: UTF8.self)
                    let combined = pendingRemainder + text
                    let components = combined.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" })
                    var lines: [String] = []
                    if let last = components.last, !combined.hasSuffix("\n") && !combined.hasSuffix("\r") {
                        pendingRemainder = String(last)
                        lines = components.dropLast().map { String($0) }
                    } else {
                        pendingRemainder = ""
                        lines = components.map { String($0) }
                    }

                    if !lines.isEmpty {
                        if let file = lines.reversed().compactMap({ RsyncRunner.extractFile(from: $0) }).first {
                            onFile(file)
                        }
                        if let speed = lines.reversed().compactMap({ RsyncRunner.parseSpeed(from: $0) }).first {
                            onSpeed(speed)
                        }
                        onLog(lines)
                        if let p = lines.compactMap({ Self.parseProgress(from: $0) }).last {
                            onProgress(p)
                        }
                        self.appendToLogFile(lines, at: config.logFileURL)
                    }
                }
            }
        }

        handler(stdout)
        handler(stderr)

        do {
            try process.run()
        } catch {
            onLog(["Failed to start: \(error.localizedDescription)"])
            process.terminate()
            onCompletion(false)
            return
        }

        self.process = process
        process.terminationHandler = { [weak self] proc in
            if let self {
                self.tearDownHandlers(for: proc)
                self.process = nil
            }
            if let out = proc.standardOutput as? Pipe {
                out.fileHandleForReading.closeFile()
            }
            if let err = proc.standardError as? Pipe {
                err.fileHandleForReading.closeFile()
            }
            onCompletion(proc.terminationStatus == 0)
        }
    }

    func cancel() {
        if let proc = process {
            tearDownHandlers(for: proc)
            proc.terminate()
        }
        process = nil
    }

    private func prepareKnownHosts() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: tempKnownHosts.path) {
            let created = fileManager.createFile(atPath: tempKnownHosts.path, contents: Data(), attributes: [.posixPermissions: 0o600])
            if !created {
                try? "".write(to: tempKnownHosts, atomically: true, encoding: .utf8)
            }
        }
    }

    private func resetLogFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: [.posixPermissions: 0o600])
    }

    private func appendToLogFile(_ lines: [String], at url: URL) {
        guard !lines.isEmpty else { return }
        let text = lines.joined(separator: "\n") + "\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
            try? handle.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func sshpassCandidatePaths() -> [String] {
        var candidates = [
            "/usr/bin/sshpass",
            "/opt/homebrew/bin/sshpass",
            "/usr/local/bin/sshpass"
        ]
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let extra = pathEnv.split(separator: ":").map { "\($0)/sshpass" }
            candidates.append(contentsOf: extra)
        }
        return Array(Set(candidates))
    }

    static func parseProgress(from line: String) -> Double? {
        guard let percentRange = line.range(of: #"(\d{1,3})%"#, options: .regularExpression) else {
            return nil
        }
        let percentString = String(line[percentRange]).replacingOccurrences(of: "%", with: "")
        guard let value = Double(percentString) else { return nil }
        return min(max(value / 100.0, 0), 1)
    }

    static func extractFile(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("%") { return nil }
        if trimmed.hasPrefix("sending") || trimmed.hasPrefix("receiving") || trimmed.hasPrefix("sent ") || trimmed.hasPrefix("total size") {
            return nil
        }
        if trimmed.hasSuffix("/") { return trimmed }
        if trimmed.contains("/") || trimmed.contains(".") {
            return trimmed
        }
        return nil
    }

    static func parseSpeed(from line: String) -> String? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return nil }
        return tokens.first { $0.contains("/s") }
    }

    private static func buildPaths(from config: RsyncConfig) -> (String, String) {
        switch config.syncDirection {
        case .push:
            let source = normalizedSourcePath(from: config.localPath)
            let destination = "\(config.username)@\(config.host):\(config.remotePath)"
            return (source, destination)
        case .pull:
            let source = "\(config.username)@\(config.host):\(config.remotePath)"
            return (source, config.localPath)
        }
    }

    private static func normalizedSourcePath(from path: String) -> String {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        guard exists, isDir.boolValue else { return path }
        return path.hasSuffix("/") ? path : path + "/"
    }
}
