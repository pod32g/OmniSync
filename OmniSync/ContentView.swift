import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: SyncViewModel
    @State private var showingSettings = false
    @State private var navPath: [Route] = []
    @State private var showEstimateSheet = false
    @Namespace private var glassEffectNamespace

    enum Route: Hashable {
        case filters
        case history
        case historyDetail(UUID)
    }

    private var currentRoute: Route? {
        navPath.last
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel, navPath: $navPath)
        } detail: {
            detailContent
        }
        .background(.regularMaterial)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
                .frame(minWidth: 560, minHeight: 500)
                .interactiveDismissDisabled(false)
        }
        .alert("Ready to Sync", isPresented: $viewModel.showingEstimate, presenting: viewModel.transferEstimate) { estimate in
            Button("Start Sync") {
                viewModel.sync()
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { }
        } message: { estimate in
            Text("Approximately \(estimate.fileCount) files, \(estimate.formattedSize)\nEstimated time: \(estimate.formattedTime)")
        }
        .alert("Pre-flight Check Results", isPresented: $viewModel.showingPreflightResults, presenting: viewModel.preflightChecks) { checks in
            if checks.canProceed {
                Button("Start Sync") {
                    viewModel.sync()
                }
                .keyboardShortcut(.defaultAction)
            }
            Button("Cancel", role: .cancel) { }
        } message: { checks in
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(checks.allResults.enumerated()), id: \.offset) { index, result in
                    HStack {
                        switch result {
                        case .pass:
                            Text("✓")
                        case .warning:
                            Text("⚠")
                        case .fail:
                            Text("✗")
                        }
                        if let message = result.message {
                            Text(message)
                        }
                    }
                }
            }
        }
        .alert("Sync Failed", isPresented: $viewModel.showingSyncError, presenting: viewModel.lastSyncError) { error in
            Button("OK", role: .cancel) { }
        } message: { error in
            VStack(alignment: .leading, spacing: 8) {
                if let description = error.errorDescription {
                    Text(description)
                        .fontWeight(.semibold)
                }
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
        .alert("Verification Complete", isPresented: $viewModel.showingVerificationResult, presenting: viewModel.verificationResult) { result in
            Button("OK", role: .cancel) { }
        } message: { result in
            Text(result)
        }
        .sheet(isPresented: $viewModel.showingConflictResolution) {
            ConflictResolutionView(viewModel: viewModel)
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func setupKeyboardShortcuts() {
        // Keyboard shortcuts are handled via CommandMenu in OmniSyncApp
        // and native button shortcuts throughout the UI
    }
}

#Preview {
    let container = AppDependencyContainer()
    ContentView(viewModel: container.makeSyncViewModel())
}

// MARK: - Sections

private extension ContentView {
    @ViewBuilder
    var detailContent: some View {
        switch currentRoute {
        case .filters:
            FiltersDetailView(viewModel: viewModel)
        case .history:
            HistoryListView(viewModel: viewModel, navPath: $navPath)
        case .historyDetail(let id):
            if let entry = viewModel.history.first(where: { $0.id == id }) {
                HistoryDetailView(entry: entry, navPath: $navPath)
            } else {
                Text("History entry not found")
                    .foregroundStyle(.secondary)
            }
        case .none:
            mainDashboard
        }
    }

    var mainDashboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ScrollView {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        connectionCard
                        pathsCard
                        filtersCard
                        autoSyncCard
                        syncCard
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 880, minHeight: 520)
    }

    var connectionCard: some View {
        CardSection(title: "NAS Connection", systemImage: "network") {
            Grid(alignment: .leading, verticalSpacing: 10) {
                GridRow {
                    FieldLabel(text: "Host")
                    HStack(spacing: 4) {
                        TextField("nas.local", text: $viewModel.host)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.host) { _ in
                                viewModel.connectionStatus = .unknown
                            }
                            .accessibilityLabel("NAS host address")
                            .accessibilityHint("Enter the hostname or IP address of your NAS device")

                        if !viewModel.recentHosts.isEmpty {
                            Menu {
                                ForEach(viewModel.recentHosts, id: \.self) { host in
                                    Button(host) {
                                        viewModel.host = host
                                    }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help("Recent hosts")
                            .accessibilityLabel("Recent hosts")
                            .accessibilityHint("Choose from recently used host addresses")
                        }
                    }
                }
                GridRow {
                    FieldLabel(text: "Username")
                    TextField("admin", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.username) { _ in
                            viewModel.connectionStatus = .unknown
                        }
                        .accessibilityLabel("SSH username")
                        .accessibilityHint("Enter your username for SSH connection")
                }
                GridRow {
                    FieldLabel(text: "Password")
                    SecureField("Optional if using keys/agent", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.password) { _ in
                            viewModel.connectionStatus = .unknown
                        }
                        .accessibilityLabel("SSH password")
                        .accessibilityHint("Enter your password, or leave empty if using SSH keys")
                }
            }
            Toggle("Strict host key checking", isOn: $viewModel.strictHostKeyChecking)
                .toggleStyle(.switch)
                .help("When enabled, rsync/ssh will require known hosts to match and will not auto-accept new hosts.")
                .accessibilityLabel("Strict host key checking")
                .accessibilityHint("When enabled, SSH will verify the host key matches known hosts")
                .accessibilityValue(viewModel.strictHostKeyChecking ? "Enabled" : "Disabled")

            HStack(spacing: 8) {
                Button("Test Connection") {
                    viewModel.testConnection()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.host.isEmpty || viewModel.username.isEmpty || viewModel.connectionStatus == .testing)
                .accessibilityLabel("Test connection")
                .accessibilityHint("Verify SSH credentials can connect to the NAS")
                .accessibilityValue(viewModel.connectionStatus == .testing ? "Testing" : "Ready")

                connectionStatusView
            }
        }
    }

    @ViewBuilder
    var connectionStatusView: some View {
        switch viewModel.connectionStatus {
        case .unknown:
            EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Testing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .help(message)
        }
    }

    var pathsCard: some View {
        CardSection(title: "Paths", systemImage: "externaldrive.badge.icloud") {
            Grid(alignment: .leading, verticalSpacing: 10) {
                GridRow {
                    FieldLabel(text: "Remote path")
                    TextField("/volume1/data", text: $viewModel.remotePath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Remote NAS path")
                        .accessibilityHint("Enter the destination path on your NAS")
                }
                GridRow {
                    FieldLabel(text: "Local source")
                    HStack(spacing: 4) {
                        TextField("/Users/me/Documents", text: $viewModel.localPath)
                            .textFieldStyle(.roundedBorder)
                            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                                handleLocalPathDrop(providers: providers)
                                return true
                            }
                            .help("Type a path or drag a folder here")
                            .accessibilityLabel("Local source folder")
                            .accessibilityHint("Enter or drag the local folder to sync")

                        if !viewModel.recentLocalPaths.isEmpty {
                            Menu {
                                ForEach(viewModel.recentLocalPaths, id: \.self) { path in
                                    Button {
                                        viewModel.localPath = path
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text((path as NSString).lastPathComponent)
                                                .font(.body)
                                            Text(path)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help("Recent folders")
                            .accessibilityLabel("Recent folders")
                            .accessibilityHint("Choose from recently synced folders")
                        }

                        Button("Choose…") {
                            chooseLocalFolder()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary)
                        .accessibilityLabel("Choose folder")
                        .accessibilityHint("Open file picker to select a local folder")
                    }
                }
            }
        }
    }

    var filtersCard: some View {
        CardSection(title: "File Filters", systemImage: "line.3.horizontal.decrease.circle") {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(FileFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("File filter type")
            .accessibilityHint("Choose which file types to sync")
            .accessibilityValue(viewModel.selectedFilter.title)

            Text(viewModel.selectedFilter.example)
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.selectedFilter == .custom {
                TextField("Custom patterns (comma separated, e.g. *.mp4,*.mkv)", text: $viewModel.customFilterPatterns)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Custom filter patterns")
                    .accessibilityHint("Enter comma-separated file patterns to sync")
            }

            TextField("Exclude patterns (comma separated, e.g. *.tmp,*.cache,node_modules)", text: $viewModel.excludePatterns)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Exclude patterns")
                .accessibilityHint("Enter comma-separated patterns to exclude from sync")

            if !viewModel.excludePatterns.isEmpty {
                Text("Excluding: \(viewModel.excludePatterns)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    var autoSyncCard: some View {
        CardSection(title: "Auto Sync", systemImage: "clock.arrow.circlepath") {
            Toggle("Enable auto sync", isOn: $viewModel.autoSyncEnabled)
                .accessibilityLabel("Enable auto sync")
                .accessibilityHint("Automatically sync at regular intervals")
                .accessibilityValue(viewModel.autoSyncEnabled ? "Enabled" : "Disabled")
            Stepper("Every \(viewModel.autoSyncIntervalMinutes) minutes", value: $viewModel.autoSyncIntervalMinutes, in: 5...240, step: 5)
                .disabled(!viewModel.autoSyncEnabled)
                .accessibilityLabel("Auto sync interval")
                .accessibilityHint("Adjust how often to automatically sync")
                .accessibilityValue("Every \(viewModel.autoSyncIntervalMinutes) minutes")
        }
    }

    var syncCard: some View {
        CardSection(title: "Sync", systemImage: "arrow.up.circle.fill") {
            HStack {
                if viewModel.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Syncing in progress")
                    Button("Cancel") {
                        viewModel.cancelSync()
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Cancel sync")
                    .accessibilityHint("Stop the current sync operation")
                }
                Spacer()
            }
            if let progress = viewModel.progress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress, total: 1.0)
                        .accessibilityLabel("Sync progress")
                        .accessibilityValue("\(Int(progress * 100)) percent complete")
                    HStack(spacing: 4) {
                        Text("Overall: \(Int(progress * 100))%")
                        if viewModel.filesTransferred > 0 {
                            Text("•")
                            if viewModel.estimatedTotalFiles > 0 {
                                Text("\(viewModel.filesTransferred) of \(viewModel.estimatedTotalFiles) files")
                            } else {
                                Text("\(viewModel.filesTransferred) files")
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                .transition(.scale.combined(with: .opacity))
            }
            Toggle("Optimize for LAN speed (no compression, whole file, faster cipher)", isOn: $viewModel.optimizeForSpeed)
                .accessibilityLabel("Optimize for LAN speed")
                .accessibilityHint("Use faster settings for local network transfers")
                .accessibilityValue(viewModel.optimizeForSpeed ? "Enabled" : "Disabled")
            Toggle("Delete remote files to match source (dangerous)", isOn: $viewModel.deleteRemoteFiles)
                .tint(.red)
                .help("Disabled by default so files on the NAS are not removed after syncing.")
                .accessibilityLabel("Delete remote files to match source")
                .accessibilityHint("Warning: removes files on NAS that are not in local folder")
                .accessibilityValue(viewModel.deleteRemoteFiles ? "Enabled" : "Disabled")
            StatusBadge(text: viewModel.statusMessage)
                .accessibilityLabel("Sync status")
                .accessibilityValue(viewModel.statusMessage)
        }
        .glassEffectID(viewModel.isSyncing ? "syncing" : "idle", in: glassEffectNamespace)
    }

    var header: some View {
        HStack {
            headerTitle
            Spacer()
            headerActions
        }
        .id("header")
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OmniSync")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("Push your local folders to NAS over rsync with optional auto-sync.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        HStack(spacing: 12) {
            headerSyncStatus
            autoSyncToggle
            settingsButton
            syncMenuButton
        }
    }

    @ViewBuilder
    private var headerSyncStatus: some View {
        if viewModel.isSyncing {
            Label("Sync in progress", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.regularMaterial))
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var autoSyncToggle: some View {
        Toggle(isOn: $viewModel.autoSyncEnabled) {
            Label("Auto Sync", systemImage: viewModel.autoSyncEnabled ? "clock.badge.checkmark" : "clock")
        }
        .toggleStyle(.switch)
        .accessibilityLabel("Auto sync toggle")
        .accessibilityHint("Enable or disable automatic syncing")
        .accessibilityValue(viewModel.autoSyncEnabled ? "Enabled" : "Disabled")
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .buttonStyle(.borderedProminent)
        .tint(.secondary)
        .accessibilityLabel("Settings")
        .accessibilityHint("Open settings window")
    }

    private var syncMenuButton: some View {
        let isEnabled = canTriggerSync

        return Menu {
            Button {
                viewModel.sync()
            } label: {
                Label("Sync Now", systemImage: "bolt.fill")
            }
            .disabled(!viewModel.canSync)

            syncAllDestinationsButton()

            Divider()

            Button {
                viewModel.estimateTransfer()
            } label: {
                Label("Estimate & Sync", systemImage: "chart.bar.fill")
            }
            .disabled(!viewModel.canSync || viewModel.isEstimating)

            Button {
                viewModel.runPreflightChecks()
            } label: {
                Label("Pre-flight Check & Sync", systemImage: "checkmark.shield.fill")
            }
            .disabled(!viewModel.canSync || viewModel.isRunningPreflightChecks)

            Button {
                viewModel.detectConflicts()
            } label: {
                Label("Detect Conflicts", systemImage: "exclamationmark.triangle.fill")
            }
            .disabled(!viewModel.canSync || viewModel.isDetectingConflicts)
        } label: {
            Label(syncMenuTitle, systemImage: syncMenuSystemImage)
        } primaryAction: {
            viewModel.sync()
        }
        .disabled(!isEnabled)
        .buttonStyle(.glassProminent)
        .tint(.accentColor)
        .shadow(color: .accentColor.opacity(isEnabled ? 0.3 : 0), radius: 12, x: 0, y: 6)
        .scaleEffect(isEnabled ? 1.0 : 0.96)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isEnabled)
        .interactiveTapScale(enabled: isEnabled)
        .accessibilityLabel(viewModel.isEstimating ? "Estimating transfer" : "Sync now")
        .accessibilityHint("Start syncing your local folder to the NAS")
        .accessibilityValue(isEnabled ? "Ready to sync" : "Not ready")
    }

    @ViewBuilder
    private func syncAllDestinationsButton() -> some View {
        if let currentProfile = viewModel.profiles.first(where: { profile in
            profile.host == viewModel.host &&
            profile.username == viewModel.username &&
            profile.remotePath == viewModel.remotePath
        }), !currentProfile.destinations.isEmpty {
            Button {
                Task {
                    await viewModel.syncToMultipleDestinations(currentProfile.destinations)
                }
            } label: {
                Label("Sync to All Destinations (\(currentProfile.destinations.count))", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!viewModel.canSync)
        }
    }

    private var syncMenuTitle: String {
        if viewModel.isEstimating {
            return "Estimating..."
        }
        if viewModel.isRunningPreflightChecks {
            return "Checking..."
        }
        return "Sync Now"
    }

    private var syncMenuSystemImage: String {
        if viewModel.isEstimating {
            return "hourglass"
        }
        if viewModel.isRunningPreflightChecks {
            return "checkmark.shield"
        }
        return "arrow.up.circle"
    }

    private var canTriggerSync: Bool {
        viewModel.canSync && !viewModel.isEstimating && !viewModel.isRunningPreflightChecks
    }

    // MARK: - UI helpers

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

    func handleLocalPathDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
            DispatchQueue.main.async {
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        viewModel.localPath = url.path
                    }
                }
            }
        }
    }
}

struct ConflictResolutionView: View {
    @ObservedObject var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resolve Conflicts")
                        .font(.title2.weight(.semibold))
                    Text("\(viewModel.conflicts.count) file(s) have conflicts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    viewModel.showingConflictResolution = false
                    dismiss()
                }
                .buttonStyle(.glass)
            }

            Divider()

            // Conflicts list
            if viewModel.conflicts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("No Conflicts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.conflicts.indices, id: \.self) { index in
                            ConflictRow(conflict: $viewModel.conflicts[index])
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            Divider()

            // Actions
            HStack(spacing: 8) {
                // Bulk actions
                Menu {
                    Button("Keep Local for All") {
                        for index in viewModel.conflicts.indices {
                            viewModel.conflicts[index].resolution = .keepLocal
                        }
                    }
                    Button("Keep Remote for All") {
                        for index in viewModel.conflicts.indices {
                            viewModel.conflicts[index].resolution = .keepRemote
                        }
                    }
                    Button("Keep Newer for All") {
                        for index in viewModel.conflicts.indices {
                            viewModel.conflicts[index].resolution = .keepNewer
                        }
                    }
                    Button("Keep Larger for All") {
                        for index in viewModel.conflicts.indices {
                            viewModel.conflicts[index].resolution = .keepLarger
                        }
                    }
                    Button("Skip All") {
                        for index in viewModel.conflicts.indices {
                            viewModel.conflicts[index].resolution = .skip
                        }
                    }
                } label: {
                    Label("Apply to All", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.glass)

                Spacer()

                Button("Proceed with Sync") {
                    viewModel.showingConflictResolution = false
                    // Apply resolutions and sync
                    applyConflictResolutions()
                    viewModel.sync()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 600, height: 550)
    }

    private func applyConflictResolutions() {
        // In a full implementation, this would modify the rsync command
        // based on the chosen resolutions. For now, we'll just proceed with sync
        // and the default rsync behavior will apply.
        // A more complete implementation would:
        // 1. For "keep local": add --ignore-existing flag
        // 2. For "keep remote": don't sync those files
        // 3. For "keep newer": use --update flag (default)
        // 4. For "skip": add to exclude list
    }
}

struct ConflictRow: View {
    @Binding var conflict: FileConflict

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File path
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                Text(conflict.path)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // File info
            HStack(spacing: 16) {
                if let localSize = conflict.localSize {
                    Label("\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file))", systemImage: "laptopcomputer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let remoteSize = conflict.remoteSize {
                    Label("\(ByteCountFormatter.string(fromByteCount: remoteSize, countStyle: .file))", systemImage: "server.rack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Resolution picker
            Picker("Resolution", selection: $conflict.resolution) {
                ForEach(ConflictResolution.allCases) { resolution in
                    Text(resolution.label).tag(resolution)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background.opacity(0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        )
    }
}
