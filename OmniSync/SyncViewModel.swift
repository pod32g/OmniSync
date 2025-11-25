import Foundation
import Combine
import AppKit

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

final class SyncViewModel: ObservableObject {
    @Published var host = ""
    @Published var username = ""
    @Published var password = ""
    @Published var remotePath = ""
    @Published var localPath = ""
    @Published var selectedFilter: FileFilter = .all
    @Published var customFilterPatterns = ""
    @Published var statusMessage = "Idle"
    @Published var isSyncing = false
    @Published var progress: Double? = nil
    @Published var log: [String] = []
    @Published var quietMode = false
    @Published var currentFile: String? = nil
    @Published var currentSpeed: String? = nil
    @Published var autoSyncEnabled = false
    @Published var autoSyncIntervalMinutes = 30

    private let maxLogLines = 500
    private let flushInterval: TimeInterval = 0.3
    let logFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("omnisync.log")
    private var runner = RsyncRunner()
    private var autoSyncTimer: Timer?
    private var lastProgressUpdate = Date.distantPast
    private var cancellables = Set<AnyCancellable>()

    deinit {
        autoSyncTimer?.invalidate()
    }

    init() {
        loadPersisted()
        setupPersistence()
    }

    var canSync: Bool {
        !host.isEmpty && !username.isEmpty && !remotePath.isEmpty && !localPath.isEmpty && !isSyncing
    }

    func sync() {
        guard canSync else { return }
        if isSyncing { return }
        log.removeAll()
        statusMessage = "Starting sync..."
        isSyncing = true
        progress = 0
        currentFile = nil
        currentSpeed = nil
        resetLogFile()

        let filterArgs = buildFilterArgs()
        let config = RsyncConfig(
            host: host,
            username: username,
            password: password,
            remotePath: remotePath,
            localPath: localPath,
            filterArgs: filterArgs,
            quietMode: quietMode,
            logFileURL: logFileURL,
            flushInterval: flushInterval
        )

        runner.run(
            config: config,
            onLog: { [weak self] lines in
                Task { @MainActor in self?.appendLogs(lines, progress: nil) }
            },
            onFile: { [weak self] file in
                Task { @MainActor in
                    self?.currentFile = file
                    self?.updateStatus()
                }
            },
            onSpeed: { [weak self] speed in
                Task { @MainActor in
                    self?.currentSpeed = speed
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
                    self?.statusMessage = success ? "Sync completed" : "Sync failed"
                    self?.isSyncing = false
                    self?.progress = nil
                    self?.currentFile = nil
                    self?.currentSpeed = nil
                }
            }
        )
    }

    func cancelSync() {
        runner.cancel()
        isSyncing = false
        statusMessage = "Sync cancelled"
        currentFile = nil
        currentSpeed = nil
    }

    func updateAutoSyncEnabled(_ enabled: Bool) {
        autoSyncEnabled = enabled
        enabled ? startAutoSyncTimer() : stopAutoSyncTimer()
    }

    func refreshAutoSyncTimerIfNeeded() {
        guard autoSyncEnabled else { return }
        startAutoSyncTimer()
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
        guard canSync else {
            Task { @MainActor in
                self.appendLogs(["Fill in connection and paths before enabling auto sync."], progress: nil)
            }
            autoSyncEnabled = false
            return
        }

        let interval = max(1, autoSyncIntervalMinutes) * 60
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.isSyncing {
                Task { @MainActor in self.appendLogs(["Auto sync skipped; a sync is already running."], progress: nil) }
                return
            }
            self.sync()
        }
    }

    private func stopAutoSyncTimer() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    private func buildFilterArgs() -> [String] {
        let filter = selectedFilter
        if filter == .all {
            return []
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

        guard !patterns.isEmpty else { return [] }
        return ["--include=*/"] + patterns.map { "--include=\($0)" } + ["--exclude=*"]
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
        bind($password, key: "password")
        bind($remotePath, key: "remotePath")
        bind($localPath, key: "localPath")
        bind($customFilterPatterns, key: "customFilterPatterns")
        bind($quietMode, key: "quietMode")
        bind($autoSyncEnabled, key: "autoSyncEnabled")
        bind($autoSyncIntervalMinutes, key: "autoSyncIntervalMinutes")

        $selectedFilter
            .sink { filter in
                defaults.set(filter.rawValue, forKey: "selectedFilter")
            }
            .store(in: &cancellables)
    }

    private func loadPersisted() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "host") ?? ""
        username = defaults.string(forKey: "username") ?? ""
        password = defaults.string(forKey: "password") ?? ""
        remotePath = defaults.string(forKey: "remotePath") ?? ""
        localPath = defaults.string(forKey: "localPath") ?? ""
        customFilterPatterns = defaults.string(forKey: "customFilterPatterns") ?? ""
        quietMode = defaults.object(forKey: "quietMode") as? Bool ?? false
        autoSyncEnabled = defaults.object(forKey: "autoSyncEnabled") as? Bool ?? false
        autoSyncIntervalMinutes = defaults.object(forKey: "autoSyncIntervalMinutes") as? Int ?? 30
        if let filterRaw = defaults.string(forKey: "selectedFilter"), let filter = FileFilter(rawValue: filterRaw) {
            selectedFilter = filter
        }
    }
}

// MARK: - Rsync Runner

private struct RsyncConfig {
    let host: String
    let username: String
    let password: String
    let remotePath: String
    let localPath: String
    let filterArgs: [String]
    let quietMode: Bool
    let logFileURL: URL
    let flushInterval: TimeInterval
}

private final class RsyncRunner {
    private var process: Process?
    private let tempKnownHosts = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("omnisync_known_hosts")
    private let queue = DispatchQueue(label: "rsync-output-buffer", qos: .utility)

    func run(
        config: RsyncConfig,
        onLog: @escaping ([String]) -> Void,
        onFile: @escaping (String) -> Void,
        onSpeed: @escaping (String) -> Void,
        onProgress: @escaping (Double?) -> Void,
        onStart: @escaping () -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) {
        guard process == nil else {
            onLog(["A sync is already running."])
            return
        }
        prepareKnownHosts()
        resetLogFile(at: config.logFileURL)

        var sshOptions = [
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=\(tempKnownHosts.path)"
        ]
        if config.password.isEmpty {
            sshOptions += ["-o", "BatchMode=yes"]
        }
        let sshCommand = (["ssh"] + sshOptions).joined(separator: " ")
        let rsyncArgs = ["-avz", "--progress", "--delete", "-e", sshCommand] + config.filterArgs + [config.localPath, "\(config.username)@\(config.host):\(config.remotePath)"]

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
            self?.process = nil
            if let out = proc.standardOutput as? Pipe {
                out.fileHandleForReading.readabilityHandler = nil
            }
            if let err = proc.standardError as? Pipe {
                err.fileHandleForReading.readabilityHandler = nil
            }
            proc.standardOutput = nil
            proc.standardError = nil
            onCompletion(proc.terminationStatus == 0)
        }
    }

    func cancel() {
        if let proc = process {
            if let out = proc.standardOutput as? Pipe {
                out.fileHandleForReading.readabilityHandler = nil
            }
            if let err = proc.standardError as? Pipe {
                err.fileHandleForReading.readabilityHandler = nil
            }
            proc.terminationHandler = nil
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

    private static func parseProgress(from line: String) -> Double? {
        guard let percentRange = line.range(of: #"(\d{1,3})%"#, options: .regularExpression) else {
            return nil
        }
        let percentString = String(line[percentRange]).replacingOccurrences(of: "%", with: "")
        guard let value = Double(percentString) else { return nil }
        return min(max(value / 100.0, 0), 1)
    }

    private static func extractFile(from line: String) -> String? {
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

    private static func parseSpeed(from line: String) -> String? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return nil }
        return tokens.first { $0.contains("/s") }
    }
}
