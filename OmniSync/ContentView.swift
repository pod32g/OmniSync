import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ZStack(alignment: .topLeading) {
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
                                outputCard
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 880, minHeight: 520)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    ContentView(viewModel: SyncViewModel())
}

// MARK: - Sections

private extension ContentView {
    var connectionCard: some View {
        CardSection(title: "NAS Connection", systemImage: "network") {
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
            Toggle("Strict host key checking", isOn: $viewModel.strictHostKeyChecking)
                .toggleStyle(.switch)
                .help("When enabled, rsync/ssh will require known hosts to match and will not auto-accept new hosts.")
        }
    }

    var pathsCard: some View {
        CardSection(title: "Paths", systemImage: "externaldrive.badge.icloud") {
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
    }

    var filtersCard: some View {
        CardSection(title: "File Filters", systemImage: "line.3.horizontal.decrease.circle") {
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
    }

    var autoSyncCard: some View {
        CardSection(title: "Auto Sync", systemImage: "clock.arrow.circlepath") {
            Toggle("Enable auto sync", isOn: $viewModel.autoSyncEnabled)
            Stepper("Every \(viewModel.autoSyncIntervalMinutes) minutes", value: $viewModel.autoSyncIntervalMinutes, in: 5...240, step: 5)
                .disabled(!viewModel.autoSyncEnabled)
        }
    }

    var syncCard: some View {
        CardSection(title: "Sync", systemImage: "arrow.up.circle.fill") {
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
    }

    var outputCard: some View {
        CardSection(title: "Output", systemImage: "terminal.fill") {
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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(viewModel.log.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.primary)
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 220)
                    .onChange(of: viewModel.log.count) { _, _ in
                        if let last = viewModel.log.indices.last {
                            withAnimation {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
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
                        .glassEffect(.clear, in: Capsule())
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
                .buttonStyle(.glassProminent)
                .tint(.accentColor)
            }
        }
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

    func copyOutputToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func showLogFile(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
