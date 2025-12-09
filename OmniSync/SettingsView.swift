import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SyncViewModel
    @State private var profileName = ""

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scheduleCard
                    syncBehaviorCard
                    networkMonitoringCard
                    notificationsCard
                    profilesCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(.regularMaterial)
    }
}

private extension SettingsView {
    var scheduleCard: some View {
        CardSection(title: "Schedule", systemImage: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable scheduled syncs", isOn: $viewModel.schedule.enabled)
                    .accessibilityLabel("Enable scheduled syncs")
                    .accessibilityHint("Automatically run syncs on a schedule")

                if viewModel.schedule.enabled {
                    Picker("Schedule type", selection: $viewModel.schedule.type) {
                        ForEach(ScheduleType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Schedule type")

                    switch viewModel.schedule.type {
                    case .interval:
                        HStack {
                            Text("Repeat every")
                            Spacer()
                            TextField("Minutes", value: $viewModel.schedule.intervalMinutes, formatter: numberFormatter)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("minutes")
                        }
                        Text("Sync will run every \(viewModel.schedule.intervalMinutes) minutes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                    case .daily:
                        DatePicker("Time", selection: $viewModel.schedule.dailyTime, displayedComponents: .hourAndMinute)
                            .accessibilityLabel("Daily sync time")
                        Text("Sync will run every day at \(formattedTime(viewModel.schedule.dailyTime))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                    case .weekly:
                        DatePicker("Time", selection: $viewModel.schedule.weeklyTime, displayedComponents: .hourAndMinute)
                            .accessibilityLabel("Weekly sync time")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Days of week")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(Weekday.allCases) { day in
                                    Toggle(day.label, isOn: Binding(
                                        get: { viewModel.schedule.weeklyDays.contains(day) },
                                        set: { enabled in
                                            if enabled {
                                                viewModel.schedule.weeklyDays.insert(day)
                                            } else {
                                                viewModel.schedule.weeklyDays.remove(day)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        if !viewModel.schedule.weeklyDays.isEmpty {
                            let days = viewModel.schedule.weeklyDays.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.label }.joined(separator: ", ")
                            Text("Sync will run on \(days) at \(formattedTime(viewModel.schedule.weeklyTime))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select at least one day")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    var syncBehaviorCard: some View {
        CardSection(title: "Sync Behavior", systemImage: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Direction", selection: $viewModel.syncDirection) {
                    ForEach(SyncDirection.allCases) { direction in
                        Text(direction.label).tag(direction)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Sync direction")
                .accessibilityHint("Choose whether to push to NAS or pull from NAS")
                .accessibilityValue(viewModel.syncDirection.label)

                Toggle("Dry run (no changes applied)", isOn: $viewModel.dryRun)
                    .accessibilityLabel("Dry run mode")
                    .accessibilityHint("Test sync without making any changes")
                    .accessibilityValue(viewModel.dryRun ? "Enabled" : "Disabled")
                Toggle("Resume partial transfers (--partial --append-verify)", isOn: $viewModel.resumePartials)
                    .accessibilityLabel("Resume partial transfers")
                    .accessibilityHint("Continue interrupted file transfers from where they left off")
                    .accessibilityValue(viewModel.resumePartials ? "Enabled" : "Disabled")
                Toggle("Quiet mode (hide live log during sync)", isOn: $viewModel.quietMode)
                    .accessibilityLabel("Quiet mode")
                    .accessibilityHint("Hide detailed log output during sync")
                    .accessibilityValue(viewModel.quietMode ? "Enabled" : "Disabled")
                HStack {
                    Text("Bandwidth limit (KB/s)")
                    Spacer()
                    TextField("0 = unlimited", value: $viewModel.bandwidthLimitKBps, formatter: numberFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Bandwidth limit in kilobytes per second")
                        .accessibilityHint("Set to 0 for unlimited bandwidth")
                }
                Text("Set bandwidth to 0 for no cap. Pull direction copies NAS → local.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Auto-retry on failure", isOn: $viewModel.autoRetryEnabled)
                    .accessibilityLabel("Auto-retry on failure")
                    .accessibilityHint("Automatically retry failed syncs with exponential backoff")
                    .accessibilityValue(viewModel.autoRetryEnabled ? "Enabled" : "Disabled")

                if viewModel.autoRetryEnabled {
                    HStack {
                        Text("Max retry attempts")
                        Spacer()
                        Stepper("\(viewModel.maxRetryAttempts)", value: $viewModel.maxRetryAttempts, in: 1...10)
                            .accessibilityLabel("Maximum retry attempts")
                            .accessibilityValue("\(viewModel.maxRetryAttempts) attempts")
                    }
                    Text("Retries use exponential backoff: 2s, 4s, 8s, etc.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Toggle("Verify after sync (checksum)", isOn: $viewModel.verifyAfterSync)
                    .accessibilityLabel("Verify after sync")
                    .accessibilityHint("Run checksum verification after each successful sync")
                    .accessibilityValue(viewModel.verifyAfterSync ? "Enabled" : "Disabled")

                if viewModel.verifyAfterSync {
                    Text("After each sync, rsync will verify all files using checksums to ensure data integrity. This may take additional time.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var networkMonitoringCard: some View {
        CardSection(title: "Network Monitoring", systemImage: "network") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Network status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.networkStatus == .connected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.networkStatus.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Enable network monitoring", isOn: $viewModel.networkMonitoringEnabled)
                    .accessibilityLabel("Enable network monitoring")
                    .accessibilityHint("Monitor network connectivity changes")
                    .accessibilityValue(viewModel.networkMonitoringEnabled ? "Enabled" : "Disabled")

                if viewModel.networkMonitoringEnabled {
                    Toggle("Pause sync on network loss", isOn: $viewModel.pauseSyncOnNetworkLoss)
                        .accessibilityLabel("Pause sync on network loss")
                        .accessibilityHint("Automatically cancel syncs when network is lost")
                        .accessibilityValue(viewModel.pauseSyncOnNetworkLoss ? "Enabled" : "Disabled")

                    Text("When enabled, ongoing syncs will be cancelled automatically if network connection is lost.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var notificationsCard: some View {
        CardSection(title: "Notifications", systemImage: "bell") {
            Toggle("Notify when sync finishes", isOn: $viewModel.notifyOnCompletion)
                .toggleStyle(.switch)
                .accessibilityLabel("Notify when sync finishes")
                .accessibilityHint("Show a notification when sync completes")
                .accessibilityValue(viewModel.notifyOnCompletion ? "Enabled" : "Disabled")
        }
    }

    var profilesCard: some View {
        CardSection(title: "Profiles", systemImage: "rectangle.stack.person.crop") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Profile name", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Profile name")
                        .accessibilityHint("Enter a name for the new profile")
                    Button("Save current") {
                        viewModel.saveCurrentProfile(named: profileName)
                        profileName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save current configuration")
                    .accessibilityHint("Save your current settings as a new profile")
                }

                if viewModel.profiles.isEmpty {
                    ContentUnavailableView {
                        Label("No Profiles", systemImage: "rectangle.stack.person.crop")
                    } description: {
                        Text("Save your current configuration to quickly switch between different NAS devices and settings.")
                    } actions: {
                        Button("Create First Profile") {
                            profileName = "My NAS"
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.profiles) { profile in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name).font(.headline)
                                    Text("\(profile.username)@\(profile.host)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Local: \(profile.localPath)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("Remote: \(profile.remotePath)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(spacing: 6) {
                                    Button("Apply") { viewModel.applyProfile(profile) }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .accessibilityLabel("Apply profile \(profile.name)")
                                        .accessibilityHint("Load this profile's settings")
                                    Button(role: .destructive) {
                                        viewModel.deleteProfile(profile)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Delete profile \(profile.name)")
                                    .accessibilityHint("Permanently remove this profile")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout for weekday buttons

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
