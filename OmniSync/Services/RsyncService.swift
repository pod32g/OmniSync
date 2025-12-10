import Foundation

final class RsyncService: RsyncServiceProtocol {
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
        let (source, destination) = buildPaths(from: config)
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
                        if let file = lines.reversed().compactMap({ Self.extractFile(from: $0) }).first {
                            onFile(file)
                        }
                        if let speed = lines.reversed().compactMap({ Self.parseSpeed(from: $0) }).first {
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

    func buildFilterArgs(
        selectedFilter: FileFilter,
        customFilterPatterns: String,
        excludePatterns: String
    ) -> [String] {
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
        if selectedFilter == .all {
            return args // Return only exclusions if any, or empty array
        }

        var patterns = selectedFilter.patterns

        if selectedFilter == .custom {
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

    func testConnection(
        host: String,
        username: String,
        password: String,
        strictHostKeyChecking: Bool,
        completion: @escaping (ConnectionStatus) -> Void
    ) {
        Task.detached {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

            var sshArgs = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=\(strictHostKeyChecking ? "yes" : "accept-new")"
            ]

            if !password.isEmpty {
                // Try to find sshpass
                let candidates = [
                    "/usr/bin/sshpass",
                    "/opt/homebrew/bin/sshpass",
                    "/usr/local/bin/sshpass"
                ]

                if let sshPassPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                    process.executableURL = URL(fileURLWithPath: sshPassPath)
                    sshArgs = ["-p", password, "ssh"] + sshArgs + ["\(username)@\(host)", "echo", "OK"]
                } else {
                    sshArgs.append(contentsOf: ["\(username)@\(host)", "echo", "OK"])
                }
            } else {
                sshArgs.append(contentsOf: ["\(username)@\(host)", "echo", "OK"])
            }

            process.arguments = sshArgs

            do {
                try process.run()
                process.waitUntilExit()

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    if process.terminationStatus == 0 {
                        completion(.success("Connection successful!"))
                    } else {
                        let message = errorOutput.isEmpty ? "Connection failed (exit code: \(process.terminationStatus))" : String(errorOutput.prefix(100))
                        completion(.failed(message))
                    }
                }
            } catch {
                await MainActor.run {
                    completion(.failed("Failed to run SSH: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func tearDownHandlers(for proc: Process) {
        if let out = proc.standardOutput as? Pipe {
            out.fileHandleForReading.readabilityHandler = nil
        }
        if let err = proc.standardError as? Pipe {
            err.fileHandleForReading.readabilityHandler = nil
        }
        proc.terminationHandler = nil
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

    private func buildPaths(from config: RsyncConfig) -> (String, String) {
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

    private func normalizedSourcePath(from path: String) -> String {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        guard exists, isDir.boolValue else { return path }
        return path.hasSuffix("/") ? path : path + "/"
    }

    // MARK: - Static Parsing Methods

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
}
