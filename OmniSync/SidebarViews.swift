import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SyncViewModel
    @Binding var navPath: [ContentView.Route]
    @State private var showingNewProfileSheet = false
    @State private var newProfileName = ""

    var body: some View {
        List {
            Section("Connection") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.applyBaselineProfile()
                        navPath.removeAll()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summaryTitle(host: viewModel.host, user: viewModel.username))
                                    .font(.body.weight(.semibold))
                                if !viewModel.remotePath.isEmpty {
                                    Text(viewModel.remotePath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                HStack {
                    Text("Saved connections")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showingNewProfileSheet = true
                    } label: {
                        Label("New", systemImage: "plus.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
                if viewModel.profiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No saved connections yet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("The current connection acts as the default. Click the + button above to save it.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.body.weight(.semibold))
                                Text(summaryTitle(host: profile.host, user: profile.username))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(profile.remotePath)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isActive(profile) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Button {
                                viewModel.applyProfile(profile)
                            } label: {
                                Label("Apply", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        viewModel.deleteProfile(profile)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("Actions") {
                Button {
                    navPath = [.filters]
                } label: {
                    Label("File Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.plain)

                Button {
                    navPath = [.history]
                } label: {
                    Label("Sync History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showingNewProfileSheet) {
            newProfileSheet
        }
    }
}

struct FiltersDetailView: View {
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

struct HistoryListView: View {
    @ObservedObject var viewModel: SyncViewModel
    @Binding var navPath: [ContentView.Route]

    var body: some View {
        List {
            if viewModel.history.isEmpty {
                ContentUnavailableView {
                    Label("No Sync History", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Run a sync to see past transactions and their logs.")
                } actions: {
                    Button("Go to Dashboard") {
                        navPath.removeAll()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.history) { entry in
                    Button {
                        navPath = [.history, .historyDetail(entry.id)]
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(entry.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                    Text(entryTitle(entry))
                        .font(.headline)
                    Text("\(formattedDate(entry.startedAt)) · \(entry.direction.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                            Text(entry.success ? "Success" : "Failed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Sync History")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func entryTitle(_ entry: SyncHistoryEntry) -> String {
        let localName = (entry.localPath as NSString).lastPathComponent
        let remoteName = (entry.remotePath as NSString).lastPathComponent
        return "\(localName) → \(remoteName)"
    }

    private func summaryTitle(host: String, user: String) -> String {
        if host.isEmpty && user.isEmpty { return "Not set" }
        if user.isEmpty { return host }
        return "\(user) @ \(host)"
    }
}

struct HistoryDetailView: View {
    let entry: SyncHistoryEntry
    @Binding var navPath: [ContentView.Route]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                logs
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Run Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if navPath.count > 1 {
                        navPath.removeLast()
                    } else {
                        navPath = []
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.success ? "Success" : "Failed")
                    .font(.headline)
                    .foregroundStyle(entry.success ? .green : .red)
                Spacer()
                Text(entry.direction.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Started \(formattedDate(entry.startedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Local: \(entry.localPath)")
                .font(.subheadline)
            Text("Remote: \(entry.remotePath)")
                .font(.subheadline)
            let filterTitle = FileFilter(rawValue: entry.filter)?.title ?? entry.filter
            Text("Filter: \(filterTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !entry.customFilterPatterns.isEmpty {
                Text("Custom: \(entry.customFilterPatterns)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var logs: some View {
        CardSection(title: "Logs", systemImage: "terminal") {
            if entry.logLines.isEmpty {
                Text("No logs captured for this run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entry.logLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                }
                .frame(minHeight: 220)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private extension SidebarView {
    @ViewBuilder
    var newProfileSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Connection")
                .font(.title2.weight(.semibold))
            Text("Save the current host/paths/filters as a reusable profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    showingNewProfileSheet = false
                    newProfileName = ""
                }
                .buttonStyle(.glass)
                Button("Save") {
                    viewModel.saveCurrentProfile(named: newProfileName)
                    showingNewProfileSheet = false
                    newProfileName = ""
                }
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    func summaryTitle(host: String, user: String) -> String {
        if host.isEmpty && user.isEmpty { return "Not set" }
        if user.isEmpty { return host }
        return "\(user) @ \(host)"
    }

    func applyCurrentSnapshot() {
        // Re-apply current in-memory fields as the active selection.
        viewModel.applyProfile(
            SyncProfile(
                id: UUID(),
                name: "Current",
                host: viewModel.host,
                username: viewModel.username,
                remotePath: viewModel.remotePath,
                localPath: viewModel.localPath,
                filter: viewModel.selectedFilter.rawValue,
                customFilterPatterns: viewModel.customFilterPatterns,
                optimizeForSpeed: viewModel.optimizeForSpeed,
                deleteRemote: viewModel.deleteRemoteFiles
            )
        )
    }

    func isActive(_ profile: SyncProfile) -> Bool {
        profile.host == viewModel.host &&
        profile.username == viewModel.username &&
        profile.remotePath == viewModel.remotePath &&
        profile.localPath == viewModel.localPath &&
        profile.filter == viewModel.selectedFilter.rawValue &&
        profile.customFilterPatterns == viewModel.customFilterPatterns &&
        profile.optimizeForSpeed == viewModel.optimizeForSpeed &&
        profile.deleteRemote == viewModel.deleteRemoteFiles
    }
}
