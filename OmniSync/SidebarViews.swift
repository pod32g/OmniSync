import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SyncViewModel
    @Binding var navPath: [ContentView.Route]
    @State private var showingNewProfileSheet = false
    @State private var newProfileName = ""
    @State private var showingNewGroupSheet = false
    @State private var newGroupName = ""
    @State private var selectedProfileIDs: Set<UUID> = []
    @State private var selectedProfileForDestinations: SyncProfile? = nil

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
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        VStack(spacing: 4) {
                            Text("No Saved Connections")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Click the + button above to save your current connection as a profile.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(viewModel.profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.body.weight(.semibold))
                                Text(summaryTitle(host: profile.host, user: profile.username))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !profile.destinations.isEmpty {
                                    Text("\(profile.destinations.count) destination(s)")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text(profile.remotePath)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isActive(profile) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Button {
                                selectedProfileForDestinations = profile
                            } label: {
                                Label("Destinations", systemImage: "server.rack")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)

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

            Section("Groups") {
                HStack {
                    Text("Sync groups")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showingNewGroupSheet = true
                    } label: {
                        Label("New", systemImage: "plus.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }

                if viewModel.groups.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        VStack(spacing: 4) {
                            Text("No Groups")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Create groups to sync multiple profiles together.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(viewModel.groups) { group in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.body.weight(.semibold))
                                Text("\(group.profileIDs.count) profiles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Task {
                                    await viewModel.syncGroup(group)
                                }
                            } label: {
                                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                viewModel.deleteGroup(group)
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
        .sheet(isPresented: $showingNewGroupSheet) {
            newGroupSheet
        }
        .sheet(item: $selectedProfileForDestinations) { profile in
            DestinationsManagementView(viewModel: viewModel, profile: profile)
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.history.isEmpty {
                    Menu {
                        Button {
                            viewModel.exportHistory(format: .csv)
                        } label: {
                            Label("Export as CSV", systemImage: "tablecells")
                        }

                        Button {
                            viewModel.exportHistory(format: .json)
                        } label: {
                            Label("Export as JSON", systemImage: "doc.text")
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export sync history")
                }
            }
        }
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

            Divider()
                .padding(.vertical, 4)

            // Bandwidth statistics
            if entry.bytesTransferred > 0 {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Data Transferred")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: entry.bytesTransferred, countStyle: .file))
                            .font(.subheadline.weight(.medium))
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average Speed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f MB/s", entry.averageSpeedMBps))
                            .font(.subheadline.weight(.medium))
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(formattedDuration(entry.endedAt.timeIntervalSince(entry.startedAt)))
                            .font(.subheadline.weight(.medium))
                    }
                }
            } else {
                Text("No bandwidth data recorded")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let mins = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
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

    var newGroupSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Sync Group")
                .font(.title2.weight(.semibold))
            Text("Select profiles to sync together as a group.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Group name", text: $newGroupName)
                .textFieldStyle(.roundedBorder)

            if viewModel.profiles.isEmpty {
                Text("No profiles available. Create some profiles first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Profiles:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.profiles) { profile in
                                Toggle(isOn: Binding(
                                    get: { selectedProfileIDs.contains(profile.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedProfileIDs.insert(profile.id)
                                        } else {
                                            selectedProfileIDs.remove(profile.id)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.body)
                                        Text(summaryTitle(host: profile.host, user: profile.username))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    showingNewGroupSheet = false
                    newGroupName = ""
                    selectedProfileIDs.removeAll()
                }
                .buttonStyle(.glass)
                Button("Create") {
                    viewModel.createGroup(named: newGroupName, profileIDs: Array(selectedProfileIDs))
                    showingNewGroupSheet = false
                    newGroupName = ""
                    selectedProfileIDs.removeAll()
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedProfileIDs.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
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

struct DestinationsManagementView: View {
    @ObservedObject var viewModel: SyncViewModel
    let profile: SyncProfile
    @Environment(\.dismiss) private var dismiss
    @State private var destinations: [RemoteDestination]
    @State private var showingAddDestination = false
    @State private var newHost = ""
    @State private var newUsername = ""
    @State private var newRemotePath = ""

    init(viewModel: SyncViewModel, profile: SyncProfile) {
        self.viewModel = viewModel
        self.profile = profile
        self._destinations = State(initialValue: profile.destinations.isEmpty ?
            [RemoteDestination(host: profile.host, username: profile.username, remotePath: profile.remotePath)] :
            profile.destinations)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage Destinations")
                        .font(.title2.weight(.semibold))
                    Text("Configure sync destinations for \(profile.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    saveDestinations()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // Destinations list
            if destinations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No Destinations")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(destinations) { destination in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(destination.host)
                                        .font(.body.weight(.semibold))
                                    Text("\(destination.username) · \(destination.remotePath)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    destinations.removeAll { $0.id == destination.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.background.opacity(0.5))
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            // Add destination form
            if showingAddDestination {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Destination")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Host", text: $newHost)
                        .textFieldStyle(.roundedBorder)
                    TextField("Username", text: $newUsername)
                        .textFieldStyle(.roundedBorder)
                    TextField("Remote Path", text: $newRemotePath)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            showingAddDestination = false
                            newHost = ""
                            newUsername = ""
                            newRemotePath = ""
                        }
                        .buttonStyle(.glass)
                        Button("Add") {
                            destinations.append(RemoteDestination(
                                host: newHost,
                                username: newUsername,
                                remotePath: newRemotePath
                            ))
                            showingAddDestination = false
                            newHost = ""
                            newUsername = ""
                            newRemotePath = ""
                        }
                        .disabled(newHost.isEmpty || newUsername.isEmpty || newRemotePath.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.background.opacity(0.3))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
            }

            Button {
                showingAddDestination = true
            } label: {
                Label("Add Destination", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.glass)
            .disabled(showingAddDestination)

            // Sync to all button
            if !destinations.isEmpty {
                Divider()
                Button {
                    Task {
                        await viewModel.syncToMultipleDestinations(destinations)
                    }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync to All Destinations Now")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(20)
        .frame(width: 500, height: 550)
    }

    private func saveDestinations() {
        // Update the profile in viewModel
        if let index = viewModel.profiles.firstIndex(where: { $0.id == profile.id }) {
            viewModel.profiles[index].destinations = destinations
            // Also update legacy fields to first destination for backward compatibility
            if let first = destinations.first {
                viewModel.profiles[index].host = first.host
                viewModel.profiles[index].username = first.username
                viewModel.profiles[index].remotePath = first.remotePath
            }
        }
    }
}
