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
                    syncBehaviorCard
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
}
