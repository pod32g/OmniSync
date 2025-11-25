//
//  ContentView.swift
//  OmniSync
//
//  Created by David on 24/11/25.
//

import SwiftUI
import Combine
import AppKit

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
    @Published var autoSyncEnabled = false
    @Published var autoSyncIntervalMinutes = 30
    private let tempKnownHosts = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("omnisync_known_hosts")
    private let maxLogLines = 500
    private let flushInterval: TimeInterval = 0.3
    let logFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("omnisync.log")
    private var runningProcess: Process?
    private var pendingRemainder = ""
    private var lastProgressUpdate = Date.distantPast

    private var autoSyncTimer: Timer?

    deinit {
        autoSyncTimer?.invalidate()
    }

    var canSync: Bool {
        !host.isEmpty && !username.isEmpty && !remotePath.isEmpty && !localPath.isEmpty && !isSyncing
    }

    func sync() {
        guard canSync else { return }
        if runningProcess != nil {
            return
        }
        log.removeAll()
        statusMessage = "Starting sync..."
        isSyncing = true
        progress = 0
        resetLogFile()

        let remoteTarget = "\(username)@\(host):\(remotePath)"
        let filterArgs = buildFilterArgs()
        prepareKnownHosts()

        var sshOptions = [
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=\(tempKnownHosts.path)"
        ]
        if password.isEmpty {
            sshOptions += ["-o", "BatchMode=yes"]
        }
        let sshCommand = (["ssh"] + sshOptions).joined(separator: " ")

        let rsyncArgs = ["-avz", "--progress", "--delete", "-e", sshCommand] + filterArgs + [localPath, remoteTarget]

        var command: [String] = []
        let sshPassCandidates = sshpassCandidatePaths()
        let sshPassPath = sshPassCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        if !password.isEmpty, let sshPassPath {
            Task { @MainActor in
                self.appendLogs(["Using sshpass at \(sshPassPath)"], progress: nil)
            }
            command = [sshPassPath, "-p", password, "rsync"] + rsyncArgs
        } else {
            command = ["rsync"] + rsyncArgs
            if !password.isEmpty && sshPassPath == nil {
                Task { @MainActor in
                    self.appendLogs(["sshpass not found in common paths; falling back to key/agent auth."], progress: nil)
                }
            }
        }

        Task.detached { [weak self] in
            await self?.runProcess(command: command)
        }
    }

    func updateAutoSyncEnabled(_ enabled: Bool) {
        autoSyncEnabled = enabled
        enabled ? startAutoSyncTimer() : stopAutoSyncTimer()
    }

    func refreshAutoSyncTimerIfNeeded() {
        guard autoSyncEnabled else { return }
        startAutoSyncTimer()
    }

    @MainActor
    private func appendLogs(_ lines: [String], progress latestProgress: Double?) {
        guard !lines.isEmpty || latestProgress != nil else { return }
        if !lines.isEmpty {
            emitStdout(lines)
            if !quietMode {
                log.append(contentsOf: lines)
                if log.count > maxLogLines {
                    log.removeFirst(log.count - maxLogLines)
                }
            }
            appendToLogFileAsync(lines)
        }
        if let latestProgress {
            let now = Date()
            let delta = abs((progress ?? 0) - latestProgress)
            if delta >= 0.02 || now.timeIntervalSince(lastProgressUpdate) >= 0.5 {
                progress = latestProgress
                lastProgressUpdate = now
            }
        }
    }

    func cancelSync() {
        runningProcess?.terminate()
        runningProcess = nil
        isSyncing = false
        statusMessage = "Sync cancelled"
    }

    private func emitStdout(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        let text = lines.joined(separator: "\n")
        print(text)
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

    private func runProcess(command: [String]) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        runningProcess = process
        var env = ProcessInfo.processInfo.environment
        let defaultPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(defaultPath):/opt/homebrew/bin:/usr/local/bin"
        process.environment = env
        Task { @MainActor in
            self.appendLogs(["Launching rsync to \(host)"], progress: nil)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            await MainActor.run {
                appendLogs(["Failed to start: \(error.localizedDescription)"], progress: nil)
                statusMessage = "Failed to start"
                isSyncing = false
            }
            return
        }

        installPipeHandler(stdout)
        installPipeHandler(stderr)

        process.waitUntilExit()
        let success = process.terminationStatus == 0
        await MainActor.run {
            statusMessage = success ? "Sync completed" : "Sync failed (\(process.terminationStatus))"
            isSyncing = false
            progress = nil
            runningProcess = nil
        }
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

    private func prepareKnownHosts() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: tempKnownHosts.path) {
            let created = fileManager.createFile(atPath: tempKnownHosts.path, contents: Data(), attributes: [.posixPermissions: 0o600])
            if !created {
                try? "".write(to: tempKnownHosts, atomically: true, encoding: .utf8)
            }
        }
    }

    private func resetLogFile() {
        try? FileManager.default.removeItem(at: logFileURL)
        FileManager.default.createFile(atPath: logFileURL.path, contents: Data(), attributes: [.posixPermissions: 0o600])
    }

    private func appendToLogFileAsync(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        let url = logFileURL
        Task.detached {
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
    }

    private func installPipeHandler(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            // Mirror raw rsync output to stdout for Console/profiler visibility.
            FileHandle.standardOutput.write(data)

            let text = String(decoding: data, as: UTF8.self)
            let combined = self.pendingRemainder + text

            let components = combined.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" })
            var lines: [String] = []
            if let last = components.last, !combined.hasSuffix("\n") && !combined.hasSuffix("\r") {
                self.pendingRemainder = String(last)
                lines = components.dropLast().map { String($0) }
            } else {
                self.pendingRemainder = ""
                lines = components.map { String($0) }
            }

            var progressValue: Double?
            if !lines.isEmpty {
                for line in lines {
                    if let p = self.parseProgress(from: line) {
                        progressValue = p
                    }
                }
            }

            Task { @MainActor in
                self.appendLogs(lines, progress: progressValue)
            }
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

    private func parseProgress(from line: String) -> Double? {
        // rsync --info=progress2 emits lines like "   123.45M  42%   ...".
        guard let percentRange = line.range(of: #"(\d{1,3})%"#, options: .regularExpression) else {
            return nil
        }
        let percentString = String(line[percentRange]).replacingOccurrences(of: "%", with: "")
        guard let value = Double(percentString) else { return nil }
        return min(max(value / 100.0, 0), 1)
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            card("NAS Connection", systemImage: "network") {
                                Grid(alignment: .leading, verticalSpacing: 10) {
                                    GridRow {
                                        FieldLabel(text: "Host")
                                        TextField("nas.local", text: $viewModel.host)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    GridRow {
                                        FieldLabel(text: "Username")
                                        TextField("admin", text: $viewModel.username)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    GridRow {
                                        FieldLabel(text: "Password")
                                        SecureField("Optional if using keys/agent", text: $viewModel.password)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }

                            card("Paths", systemImage: "externaldrive.badge.icloud") {
                                Grid(alignment: .leading, verticalSpacing: 10) {
                                    GridRow {
                                        FieldLabel(text: "Remote path")
                                        TextField("/volume1/data", text: $viewModel.remotePath)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    GridRow {
                                        FieldLabel(text: "Local source")
                                        HStack {
                                            TextField("/Users/me/Documents", text: $viewModel.localPath)
                                                .textFieldStyle(.roundedBorder)
                                            Button("Choose…") {
                                                chooseLocalFolder()
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }

                            card("File Filters", systemImage: "line.3.horizontal.decrease.circle") {
                                Picker("Filter", selection: $viewModel.selectedFilter) {
                                    ForEach(FileFilter.allCases) { filter in
                                        Text(filter.title).tag(filter)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text(viewModel.selectedFilter.example)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if viewModel.selectedFilter == .custom {
                                    TextField("Custom patterns (comma separated, e.g. *.mp4,*.mkv)", text: $viewModel.customFilterPatterns)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            card("Auto Sync", systemImage: "clock.arrow.circlepath") {
                                Stepper("Every \(viewModel.autoSyncIntervalMinutes) minutes", value: $viewModel.autoSyncIntervalMinutes, in: 5...240, step: 5)
                                    .disabled(!viewModel.autoSyncEnabled)
                            }
                            .onChange(of: viewModel.autoSyncEnabled) { _, newValue in
                                viewModel.updateAutoSyncEnabled(newValue)
                            }
                            .onChange(of: viewModel.autoSyncIntervalMinutes) { _, _ in
                                viewModel.refreshAutoSyncTimerIfNeeded()
                            }

                            card("Sync", systemImage: "arrow.up.circle.fill") {
                                HStack {
                                    if viewModel.isSyncing {
                                        ProgressView()
                                            .controlSize(.small)
                                        Button("Cancel") {
                                            viewModel.cancelSync()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    Spacer()
                                }
                                if let progress = viewModel.progress {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ProgressView(value: progress, total: 1.0)
                                        Text("Overall: \(Int(progress * 100))%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                                StatusBadge(text: viewModel.statusMessage)
                            }

                            card("Output", systemImage: "terminal.fill") {
                                HStack {
                                    Text("Recent output")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Toggle("Quiet", isOn: $viewModel.quietMode)
                                        .toggleStyle(.switch)
                                    Button("Show Log File") {
                                        showLogFile(viewModel.logFileURL)
                                    }
                                    .buttonStyle(.bordered)
                                    Button("Copy") {
                                        copyOutputToPasteboard(viewModel.log.joined(separator: "\n"))
                                    }
                                    .buttonStyle(.bordered)
                                }
                                if !viewModel.quietMode && !viewModel.log.isEmpty {
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 6) {
                                            ForEach(Array(viewModel.log.enumerated()), id: \.offset) { _, line in
                                                Text(line)
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(minHeight: 220)
                                } else if viewModel.quietMode {
                                    Text("Quiet mode enabled. Live log hidden. Use \"Show Log File\" to view output.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text("No output yet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 880, minHeight: 520)
        }
    }
}

#Preview {
    ContentView(viewModel: SyncViewModel())
}

// MARK: - Components

private struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .leading)
    }
}

private struct StatusBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(text.lowercased().contains("fail") ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                .frame(width: 10, height: 10)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        List {
            Section("Connection") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.host.isEmpty ? "No host set" : viewModel.host)
                        .font(.body.weight(.semibold))
                    Text(viewModel.username.isEmpty ? "Username not set" : viewModel.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.remotePath.isEmpty {
                    Text(viewModel.remotePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                NavigationLink {
                    FiltersDetailView(viewModel: viewModel)
                } label: {
                    Label("File Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

        }
        .listStyle(.sidebar)
    }
}

private struct FiltersDetailView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        Form {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(FileFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.selectedFilter.example)
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.selectedFilter == .custom {
                Section("Custom patterns") {
                    TextField("Comma separated (e.g. *.mp4,*.jpg)", text: $viewModel.customFilterPatterns)
                }
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}

private extension ContentView {
    func card<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.headline)
                Spacer()
            }
            Divider()
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private extension ContentView {
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("OmniSync")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("Push your local folders to NAS over rsync with optional auto-sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                if viewModel.isSyncing {
                    Label("Sync in progress", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                        )
                }

                Toggle(isOn: $viewModel.autoSyncEnabled) {
                    Label("Auto Sync", systemImage: viewModel.autoSyncEnabled ? "clock.badge.checkmark" : "clock")
                }
                .toggleStyle(.switch)

                Button {
                    viewModel.sync()
                } label: {
                    Label("Sync Now", systemImage: "arrow.up.circle")
                }
                .disabled(!viewModel.canSync)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.localPath = url.path
        }
    }

    func copyOutputToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func showLogFile(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
