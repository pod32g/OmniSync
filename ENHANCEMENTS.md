# OmniSync Enhancement Roadmap

This document outlines potential enhancements for OmniSync, organized by category and priority.

## Priority Levels
- **P0**: Critical - Core functionality improvements
- **P1**: High - Significant user value
- **P2**: Medium - Nice to have
- **P3**: Low - Future consideration

## Difficulty Estimates
- **Easy**: 1-4 hours
- **Medium**: 4-16 hours
- **Hard**: 16+ hours

---

## 🎨 Liquid Glass Enhancements

### LG-1: Interactive Button Modifiers
**Priority**: P1 | **Difficulty**: Easy | **Impact**: High

Add `.interactive` modifier to buttons for scaling, bouncing, and shimmer effects on interaction.

**Implementation**:
```swift
// ContentView.swift:223
Button {
    viewModel.sync()
} label: {
    Label("Sync Now", systemImage: "arrow.up.circle")
}
.disabled(!viewModel.canSync)
.buttonStyle(.glassProminent)
.tint(.accentColor)
.interactive() // Add this modifier
```

**Files affected**:
- ContentView.swift:223
- SettingsView.swift (all buttons)
- SidebarViews.swift (all buttons)

**Benefits**:
- More engaging user experience
- Follows Liquid Glass design principles
- Native macOS 26 feel

---

### LG-2: Glass Effect Transitions
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Use `.glassEffectID()` for smooth morphing between sync states (idle → syncing → complete).

**Implementation**:
```swift
// ContentView.swift:158
var syncCard: some View {
    CardSection(title: "Sync", systemImage: "arrow.up.circle.fill") {
        // ... content
    }
    .glassEffectID(viewModel.isSyncing ? "syncing" : "idle")
}
```

**Benefits**:
- Smooth visual transitions
- Reduces visual jarring during state changes
- Professional polish

---

### LG-3: Enhanced Cancel Button Style
**Priority**: P1 | **Difficulty**: Easy | **Impact**: Low

Change Cancel button from `.bordered` to `.glass` for consistency.

**Current**: ContentView.swift:167
```swift
Button("Cancel") {
    viewModel.cancelSync()
}
.buttonStyle(.bordered) // Change to .glass
```

**Recommended**:
```swift
Button("Cancel") {
    viewModel.cancelSync()
}
.buttonStyle(.glass)
```

---

### LG-4: Menu Bar Glass Styling
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Apply glass effects to MenuBarExtra popup content.

**Files affected**: OmniSyncApp.swift:40-88

**Implementation**:
- Wrap MenuBarExtra content in GlassEffectContainer
- Apply .glassEffect() to action cards
- Use .glassProminent for primary buttons

---

### LG-5: Floating Action Button Enhancement
**Priority**: P2 | **Difficulty**: Easy | **Impact**: Medium

Make "Sync Now" button more prominent with enhanced shadow and glow.

**Implementation**:
```swift
Button { ... }
.buttonStyle(.glassProminent)
.tint(.accentColor)
.shadow(color: .accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
.scaleEffect(viewModel.canSync ? 1.0 : 0.95)
.animation(.spring(response: 0.3), value: viewModel.canSync)
```

---

## ✨ UX/UI Improvements

### UX-1: Drag & Drop for Folders
**Priority**: P1 | **Difficulty**: Medium | **Impact**: High

Allow dragging folders onto local path field instead of clicking "Choose…".

**Implementation**:
```swift
TextField("/Users/me/Documents", text: $viewModel.localPath)
    .textFieldStyle(.roundedBorder)
    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
        providers.first?.loadItem(forTypeIdentifier: "public.file-url") { data, error in
            if let data = data as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil),
               url.hasDirectoryPath {
                DispatchQueue.main.async {
                    viewModel.localPath = url.path
                }
            }
        }
        return true
    }
```

**Files affected**: ContentView.swift:115-122

---

### UX-2: Connection Testing
**Priority**: P0 | **Difficulty**: Medium | **Impact**: High

Add "Test Connection" button to verify SSH credentials before syncing.

**Implementation**:
1. Add new method to SyncViewModel:
```swift
@Published var connectionStatus: ConnectionStatus = .unknown

enum ConnectionStatus {
    case unknown
    case testing
    case success
    case failed(String)
}

func testConnection() async {
    connectionStatus = .testing
    // Run: ssh -o BatchMode=yes -o ConnectTimeout=5 user@host "echo OK"
    // Parse output and update connectionStatus
}
```

2. Add button to NAS Connection card:
```swift
Button("Test Connection") {
    Task { await viewModel.testConnection() }
}
.buttonStyle(.bordered)
.disabled(viewModel.host.isEmpty || viewModel.username.isEmpty)
```

**Files affected**:
- SyncViewModel.swift (new methods)
- ContentView.swift:88-111 (add button)

**Benefits**:
- Prevents failed syncs due to bad credentials
- Gives user confidence before large transfers
- Helps debug connection issues

---

### UX-3: Transfer Estimates
**Priority**: P1 | **Difficulty**: Hard | **Impact**: High

Show estimated transfer size and time before starting sync.

**Implementation**:
1. Add dry-run analysis before real sync:
```swift
struct TransferEstimate {
    let fileCount: Int
    let totalBytes: Int64
    let estimatedSeconds: Int
}

func estimateTransfer() async -> TransferEstimate? {
    // Run rsync with --dry-run --stats
    // Parse output for file count and bytes
    // Estimate time based on optimizeForSpeed setting
}
```

2. Show alert/sheet with estimate before sync:
```swift
.alert("Ready to Sync", isPresented: $showingEstimate) {
    Button("Start Sync") { viewModel.sync() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("~\(estimate.fileCount) files, \(estimate.formattedSize), est. \(estimate.formattedTime)")
}
```

**Files affected**:
- SyncViewModel.swift (new estimation logic)
- ContentView.swift (show estimate UI)

---

### UX-4: File Count Progress
**Priority**: P1 | **Difficulty**: Medium | **Impact**: Medium

Display "X of Y files synced" alongside percentage.

**Implementation**:
1. Parse rsync output for file counts
2. Add to SyncViewModel:
```swift
@Published var filesTransferred: Int = 0
@Published var totalFiles: Int = 0
```

3. Update UI in ContentView.swift:174-177:
```swift
VStack(alignment: .leading, spacing: 4) {
    ProgressView(value: progress, total: 1.0)
    HStack {
        Text("Overall: \(Int(progress * 100))%")
        if totalFiles > 0 {
            Text("• \(filesTransferred) of \(totalFiles) files")
        }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
}
```

**Files affected**:
- SyncViewModel.swift (parse file counts)
- RsyncRunner.swift:910-931 (extract from output)
- ContentView.swift:171-179 (update UI)

---

### UX-5: Better Empty States
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Add illustrations and helpful prompts when history/profiles are empty.

**Current empty states**:
- SidebarViews.swift:52-54 (profiles)
- SidebarViews.swift:148-155 (history)
- SettingsView.swift:92-95 (profiles)

**Implementation**:
```swift
ContentUnavailableView {
    Label("No Profiles Yet", systemImage: "rectangle.stack.person.crop")
} description: {
    Text("Save your current connection to quickly switch between NAS devices.")
} actions: {
    Button("Save Current Profile") {
        showingNewProfileSheet = true
    }
    .buttonStyle(.borderedProminent)
}
```

**Benefits**:
- More welcoming for new users
- Guides users toward key features
- Professional appearance

---

### UX-6: Enhanced Keyboard Shortcuts
**Priority**: P2 | **Difficulty**: Easy | **Impact**: Low

Add more keyboard shortcuts for common actions.

**Proposed shortcuts**:
- `Cmd+T`: Test Connection
- `Cmd+,`: Settings (standard)
- `Cmd+H`: Show History
- `Cmd+P`: Manage Profiles
- `Cmd+O`: Choose Local Folder
- `Escape`: Cancel sync (when running)

**Files affected**: OmniSyncApp.swift:28-38 (CommandMenu)

---

### UX-7: Quick Access Menu
**Priority**: P3 | **Difficulty**: Medium | **Impact**: Low

Show recent folders and hosts in a dropdown for quick access.

**Implementation**:
- Track 5 most recent local paths and hosts
- Display in menu above connection fields
- Clicking fills in the fields

---

## 🚀 Feature Enhancements

### FE-1: Scheduled Syncs
**Priority**: P1 | **Difficulty**: Hard | **Impact**: High

Allow scheduling syncs at specific times, not just intervals.

**Implementation**:
1. Add scheduling model:
```swift
struct SyncSchedule: Codable {
    enum Frequency {
        case once(Date)
        case daily(hour: Int, minute: Int)
        case weekly(day: Int, hour: Int, minute: Int)
        case interval(minutes: Int) // existing behavior
    }

    var frequency: Frequency
    var enabled: Bool
}
```

2. Add UI in Settings:
```swift
Picker("Schedule Type", selection: $scheduleType) {
    Text("Interval").tag(ScheduleType.interval)
    Text("Daily").tag(ScheduleType.daily)
    Text("Weekly").tag(ScheduleType.weekly)
}

if scheduleType == .daily {
    DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
}
```

3. Replace Timer with more sophisticated scheduling

**Files affected**:
- SyncViewModel.swift:159-170, 360-398 (scheduling logic)
- SettingsView.swift (new UI)

---

### FE-2: Exclude Patterns
**Priority**: P1 | **Difficulty**: Medium | **Impact**: High

Add file exclusion patterns (currently only has inclusion filters).

**Implementation**:
1. Add to SyncViewModel:
```swift
@Published var excludePatterns = ""
```

2. Update buildFilterArgs() in SyncViewModel.swift:400-421:
```swift
var args: [String] = []

// Exclusions first
if !excludePatterns.isEmpty {
    let patterns = excludePatterns.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    args += patterns.map { "--exclude=\($0)" }
}

// Then inclusions
// ... existing logic
```

3. Add UI field:
```swift
TextField("Exclude patterns (e.g., *.tmp,*.cache)", text: $viewModel.excludePatterns)
    .textFieldStyle(.roundedBorder)
```

**Files affected**:
- SyncViewModel.swift
- ContentView.swift:136-154 (filters card)

**Benefits**:
- More flexible file filtering
- Prevents syncing system files, caches, etc.
- Common use case for rsync users

---

### FE-3: Two-Way Sync Detection
**Priority**: P2 | **Difficulty**: Hard | **Impact**: Medium

Warn about conflicts when doing bidirectional syncs.

**Implementation**:
1. Before sync, detect if both sides have changes
2. Show conflict resolution UI:
   - Keep local
   - Keep remote
   - Keep both (rename)
   - Skip file
   - Newest wins

**Complexity**: Requires tracking file modification times on both sides

---

### FE-4: Sync Verification
**Priority**: P1 | **Difficulty**: Medium | **Impact**: High

Optional checksum verification after sync completes.

**Implementation**:
1. Add setting:
```swift
@Published var verifyAfterSync = false
```

2. After successful sync, run:
```bash
rsync -avcn --checksum source dest
```

3. Report any differences found

**Files affected**:
- SyncViewModel.swift
- SettingsView.swift (add toggle)

---

### FE-5: Bandwidth Statistics
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Track total data transferred, average speeds over time.

**Implementation**:
1. Extend SyncHistoryEntry:
```swift
struct SyncHistoryEntry {
    // ... existing
    let bytesTransferred: Int64
    let durationSeconds: Double
    let averageSpeedMBps: Double
}
```

2. Parse from rsync stats output
3. Show in history detail view:
   - "Transferred: 2.3 GB"
   - "Average speed: 45.2 MB/s"
   - "Duration: 51 seconds"

4. Add statistics view:
   - Total data synced all time
   - Average sync time
   - Most synced paths
   - Charts/graphs

**Files affected**:
- SyncViewModel.swift:124-135, 588-621
- SidebarViews.swift:206-295 (history detail)

---

### FE-6: Multiple Destinations
**Priority**: P3 | **Difficulty**: Hard | **Impact**: Medium

Sync to multiple NAS devices simultaneously.

**Implementation**:
- Allow adding multiple remote hosts per profile
- Run syncs in parallel
- Show combined progress

**Complexity**: Requires significant refactoring

---

### FE-7: Sync Groups
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Create groups of folders to sync together.

**Implementation**:
```swift
struct SyncGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var profiles: [SyncProfile]
}

func syncGroup(_ group: SyncGroup) async {
    for profile in group.profiles {
        applyProfile(profile)
        await sync()
    }
}
```

**UI**: New "Groups" section in sidebar

---

### FE-8: History Export
**Priority**: P2 | **Difficulty**: Easy | **Impact**: Low

Export sync logs as CSV/JSON for analysis.

**Implementation**:
```swift
func exportHistory(format: ExportFormat) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [format.contentType]
    if panel.runModal() == .OK, let url = panel.url {
        switch format {
        case .csv:
            let csv = history.map { "\($0.startedAt),\($0.success),\($0.direction)" }
            try? csv.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        case .json:
            let data = try? JSONEncoder().encode(history)
            try? data?.write(to: url)
        }
    }
}
```

**Files affected**: SidebarViews.swift:142-184 (history list)

---

## 🛡️ Reliability & Error Handling

### RE-1: Pre-flight Checks
**Priority**: P0 | **Difficulty**: Medium | **Impact**: High

Validate paths exist, check disk space, test network before sync.

**Implementation**:
```swift
struct PreflightCheck {
    enum Result {
        case pass
        case warning(String)
        case fail(String)
    }

    func validate() async -> [Result] {
        var results: [Result] = []

        // Check local path exists
        if !FileManager.default.fileExists(atPath: viewModel.localPath) {
            results.append(.fail("Local path does not exist"))
        }

        // Check disk space
        if let available = try? URL(fileURLWithPath: viewModel.localPath)
            .resourceValues(forKeys: [.volumeAvailableCapacityKey])
            .volumeAvailableCapacity,
           available < 1_000_000_000 { // < 1GB
            results.append(.warning("Less than 1GB free space"))
        }

        // Test network
        let reachable = await testConnection()
        if !reachable {
            results.append(.fail("Cannot reach remote host"))
        }

        return results
    }
}
```

**Show results before sync in a modal sheet**

**Files affected**:
- SyncViewModel.swift (new validation)
- ContentView.swift (show validation UI)

---

### RE-2: Better Error Messages
**Priority**: P0 | **Difficulty**: Medium | **Impact**: High

Parse rsync errors and show user-friendly explanations.

**Implementation**:
```swift
enum SyncError: LocalizedError {
    case authenticationFailed
    case networkUnreachable
    case permissionDenied(path: String)
    case diskFull
    case pathNotFound(path: String)
    case hostKeyChanged
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Check your username and password."
        case .networkUnreachable:
            return "Cannot reach the remote host. Check your network connection."
        case .permissionDenied(let path):
            return "Permission denied for: \(path)"
        case .diskFull:
            return "Not enough disk space on the destination."
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .hostKeyChanged:
            return "Host key verification failed. The remote host's key has changed."
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "Try using SSH keys instead of password, or verify your credentials."
        case .networkUnreachable:
            return "Make sure you're connected to the network and the host is reachable."
        case .permissionDenied:
            return "Check file permissions on the remote system."
        case .diskFull:
            return "Free up space on the destination drive."
        case .pathNotFound:
            return "Verify the path exists and is typed correctly."
        case .hostKeyChanged:
            return "Remove the old key from ~/.ssh/known_hosts or use strict host key checking."
        default:
            return nil
        }
    }
}

func parseRsyncError(from output: String) -> SyncError {
    if output.contains("Permission denied") {
        return .permissionDenied(path: extractPath(from: output))
    } else if output.contains("No route to host") || output.contains("Connection refused") {
        return .networkUnreachable
    } else if output.contains("Authentication failed") {
        return .authenticationFailed
    }
    // ... more patterns
    return .unknown(message: output)
}
```

**Show errors in alert with recovery suggestions**

**Files affected**:
- SyncViewModel.swift (error parsing)
- RsyncRunner.swift (detect errors)

---

### RE-3: Network Monitoring
**Priority**: P1 | **Difficulty**: Hard | **Impact**: High

Pause/resume on network interruption.

**Implementation**:
1. Use NWPathMonitor to detect network changes:
```swift
import Network

let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    if path.status == .unsatisfied {
        // Network lost - pause sync
        pauseSync()
    } else if path.status == .satisfied {
        // Network restored - offer to resume
        showResumePrompt()
    }
}
```

2. Store sync state to resume:
```swift
struct SyncState: Codable {
    let config: RsyncConfig
    let startTime: Date
    let lastFile: String?
}
```

**Files affected**:
- SyncViewModel.swift (network monitoring)
- RsyncRunner.swift (pause/resume logic)

---

### RE-4: Retry Logic
**Priority**: P1 | **Difficulty**: Medium | **Impact**: High

Auto-retry failed syncs with exponential backoff.

**Implementation**:
```swift
func syncWithRetry(maxAttempts: Int = 3) async {
    var attempt = 0
    while attempt < maxAttempts {
        let success = await performSync()
        if success { return }

        attempt += 1
        let delay = pow(2.0, Double(attempt)) // 2s, 4s, 8s
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        appendLogs(["Retrying sync (attempt \(attempt + 1)/\(maxAttempts))..."], progress: nil)
    }

    statusMessage = "Sync failed after \(maxAttempts) attempts"
}
```

**Files affected**: SyncViewModel.swift:212-290

---

### RE-5: Conflict Resolution
**Priority**: P2 | **Difficulty**: Hard | **Impact**: Medium

When files differ, show options (keep newer, keep larger, skip, etc.).

**Implementation**:
1. Before sync, detect conflicts:
```bash
rsync -avun --itemize-changes source dest
```

2. Parse output for files that would be overwritten
3. Show conflict resolution UI:
```swift
struct ConflictResolutionView: View {
    let conflicts: [FileConflict]

    var body: some View {
        List(conflicts) { conflict in
            HStack {
                VStack(alignment: .leading) {
                    Text(conflict.path)
                    Text("Local: \(conflict.localSize) • Remote: \(conflict.remoteSize)")
                }
                Spacer()
                Picker("Action", selection: $conflict.resolution) {
                    Text("Keep Local").tag(Resolution.keepLocal)
                    Text("Keep Remote").tag(Resolution.keepRemote)
                    Text("Keep Newer").tag(Resolution.keepNewer)
                    Text("Skip").tag(Resolution.skip)
                }
            }
        }
    }
}
```

**Complexity**: Requires significant UI work

---

### RE-6: SSH Key Management
**Priority**: P2 | **Difficulty**: Hard | **Impact**: Medium

Help users generate/manage SSH keys within the app.

**Implementation**:
1. Add "SSH Keys" section in Settings
2. Show existing keys in ~/.ssh
3. Provide "Generate New Key" button:
```swift
func generateSSHKey(name: String) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
    process.arguments = [
        "-t", "ed25519",
        "-f", "\(NSHomeDirectory())/.ssh/\(name)",
        "-N", "", // No passphrase
        "-C", "omnisync@\(Host.current().localizedName ?? "mac")"
    ]
    try process.run()
    process.waitUntilExit()
}
```

4. Show public key for copying to NAS
5. Provide "Copy to NAS" helper

**Files affected**: New SettingsView section

---

## ♿ Accessibility

### A-1: VoiceOver Labels
**Priority**: P1 | **Difficulty**: Easy | **Impact**: High

Add explicit accessibility labels for screen readers.

**Implementation**:
```swift
// Add to all interactive elements
TextField("", text: $viewModel.host)
    .accessibilityLabel("NAS Host Address")
    .accessibilityHint("Enter the hostname or IP address of your NAS")

Button("Sync Now") { ... }
    .accessibilityLabel("Start sync")
    .accessibilityHint("Begins syncing your local folder to the NAS")
    .accessibilityValue(viewModel.canSync ? "Ready" : "Not ready")

ProgressView(value: progress)
    .accessibilityLabel("Sync progress")
    .accessibilityValue("\(Int(progress * 100)) percent complete")
```

**Files affected**: All views

**Testing**: Enable VoiceOver (Cmd+F5) and verify all controls are properly labeled

---

### A-2: Dynamic Type Support
**Priority**: P1 | **Difficulty**: Easy | **Impact**: Medium

Ensure text scales properly with system text size preferences.

**Implementation**:
- Use `.font(.body)`, `.font(.caption)` instead of fixed sizes
- Test with large text sizes in Accessibility Inspector
- Ensure layouts don't break at large sizes

**Current issue**: Some fixed frame sizes may clip text

---

### A-3: Reduced Motion Support
**Priority**: P2 | **Difficulty**: Easy | **Impact**: Low

Respect system preferences for animations.

**Implementation**:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Conditional animations
.animation(reduceMotion ? .none : .spring(response: 0.3), value: someValue)

// Or check system setting
if !UIAccessibility.isReduceMotionEnabled {
    withAnimation {
        // animate
    }
}
```

**Files affected**: Any views with animations

---

### A-4: Full Keyboard Navigation
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Ensure entire app is usable without mouse.

**Implementation**:
1. Test Tab navigation through all controls
2. Add `.focusable()` where needed
3. Handle Return key on text fields
4. Add escape key handlers

**Testing**: Navigate app using only keyboard

---

### A-5: High Contrast Color Support
**Priority**: P2 | **Difficulty**: Easy | **Impact**: Low

Ensure status indicators work in high contrast mode.

**Implementation**:
```swift
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

// Add text labels to color-only indicators
if differentiateWithoutColor {
    Text(entry.success ? "Success" : "Failed")
} else {
    Circle()
        .fill(entry.success ? Color.green : Color.red)
}
```

**Files affected**:
- SidebarViews.swift:161-176 (history status)
- StatusBadge (UIComponents.swift:112-141)

---

## 🏗️ Code Quality

### CQ-1: Unit Tests
**Priority**: P1 | **Difficulty**: Medium | **Impact**: High

Add unit tests for core logic.

**Test coverage needed**:
1. Filter pattern building (SyncViewModel.swift:400-421)
2. Progress parsing (RsyncRunner.swift:910-917)
3. File extraction (RsyncRunner.swift:919-931)
4. Speed parsing (RsyncRunner.swift:933-937)
5. Path building (RsyncRunner.swift:939-949)
6. Profile management
7. History management

**Implementation**:
```swift
// OmniSyncTests/SyncViewModelTests.swift
import XCTest
@testable import OmniSync

class SyncViewModelTests: XCTestCase {
    func testBuildFilterArgs_AllFilter() {
        let vm = SyncViewModel()
        vm.selectedFilter = .all
        let args = vm.buildFilterArgs()
        XCTAssertEqual(args, [])
    }

    func testBuildFilterArgs_VideoFilter() {
        let vm = SyncViewModel()
        vm.selectedFilter = .video
        let args = vm.buildFilterArgs()
        XCTAssertTrue(args.contains("--include=*.mp4"))
        XCTAssertTrue(args.contains("--include=*.mov"))
        XCTAssertTrue(args.contains("--exclude=*"))
    }

    func testBuildFilterArgs_CustomPatterns() {
        let vm = SyncViewModel()
        vm.selectedFilter = .custom
        vm.customFilterPatterns = "*.txt, *.pdf"
        let args = vm.buildFilterArgs()
        XCTAssertTrue(args.contains("--include=*.txt"))
        XCTAssertTrue(args.contains("--include=*.pdf"))
    }
}

class RsyncRunnerTests: XCTestCase {
    func testParseProgress() {
        XCTAssertEqual(RsyncRunner.parseProgress(from: "  42%"), 0.42)
        XCTAssertEqual(RsyncRunner.parseProgress(from: "100%"), 1.0)
        XCTAssertNil(RsyncRunner.parseProgress(from: "no percent here"))
    }

    func testExtractFile() {
        XCTAssertEqual(RsyncRunner.extractFile(from: "path/to/file.txt"), "path/to/file.txt")
        XCTAssertEqual(RsyncRunner.extractFile(from: "folder/"), "folder/")
        XCTAssertNil(RsyncRunner.extractFile(from: "sending incremental file list"))
    }

    func testParseSpeed() {
        XCTAssertEqual(RsyncRunner.parseSpeed(from: "  1.23MB/s"), "1.23MB/s")
        XCTAssertNil(RsyncRunner.parseSpeed(from: "no speed here"))
    }
}
```

**Files affected**: New test files in OmniSyncTests/

---

### CQ-2: Separate Sync Service
**Priority**: P1 | **Difficulty**: Hard | **Impact**: High

Extract rsync logic from ViewModel into dedicated service.

**Current issue**: SyncViewModel has too many responsibilities

**Implementation**:
```swift
// New file: Services/SyncService.swift
protocol SyncServiceProtocol {
    func sync(config: SyncConfig) async throws -> SyncResult
    func cancel()
    func testConnection(host: String, username: String) async -> Bool
}

class RsyncSyncService: SyncServiceProtocol {
    private var runner = RsyncRunner()

    func sync(config: SyncConfig) async throws -> SyncResult {
        // Move sync logic here
    }
}

// SyncViewModel.swift
class SyncViewModel: ObservableObject {
    private let syncService: SyncServiceProtocol

    init(syncService: SyncServiceProtocol = RsyncSyncService()) {
        self.syncService = syncService
    }

    func sync() {
        Task {
            do {
                let result = try await syncService.sync(config: buildConfig())
                handleSyncResult(result)
            } catch {
                handleSyncError(error)
            }
        }
    }
}
```

**Benefits**:
- Better separation of concerns
- Easier to test
- Could support alternative sync methods (FTP, S3, etc.)

**Files affected**:
- New Services/ directory
- SyncViewModel.swift (major refactoring)

---

### CQ-3: Proper Error Types
**Priority**: P1 | **Difficulty**: Medium | **Impact**: Medium

Create structured error enums instead of string messages.

**Implementation**:
```swift
// New file: Models/Errors.swift
enum SyncError: LocalizedError {
    case invalidConfiguration(reason: String)
    case connectionFailed(host: String)
    case authenticationFailed
    case transferFailed(exitCode: Int32)
    case cancelled
    case diskFull
    case permissionDenied(path: String)

    var errorDescription: String? { /* ... */ }
    var recoverySuggestion: String? { /* ... */ }
}

enum ValidationError: LocalizedError {
    case emptyHost
    case emptyUsername
    case invalidPath(String)
    case noSuchDirectory(String)
}
```

**Replace**: String messages in statusMessage with proper error handling

**Files affected**: All error handling throughout app

---

### CQ-4: Async/Await Modernization
**Priority**: P2 | **Difficulty**: Hard | **Impact**: Medium

Modernize async code from callbacks to async/await.

**Current**: RsyncRunner uses callbacks (SyncViewModel.swift:249-289)

**Proposed**:
```swift
// RsyncRunner.swift
func run(config: RsyncConfig) async throws -> SyncResult {
    return try await withCheckedThrowingContinuation { continuation in
        // Existing implementation, call continuation.resume() at end
    }
}

// SyncViewModel.swift
func sync() {
    Task {
        do {
            isSyncing = true
            let result = try await runner.run(config: config)
            handleSuccess(result)
        } catch {
            handleError(error)
        }
        isSyncing = false
    }
}
```

**Benefits**:
- More readable async code
- Better error handling
- Easier to compose async operations

**Complexity**: Requires significant refactoring of RsyncRunner

---

### CQ-5: Dependency Injection
**Priority**: P2 | **Difficulty**: Medium | **Impact**: Medium

Make testing easier with protocol-based dependencies.

**Implementation**:
```swift
// Protocols
protocol FileSystemProtocol {
    func fileExists(atPath: String) -> Bool
    func contentsOfDirectory(atPath: String) -> [String]
}

protocol UserDefaultsProtocol {
    func string(forKey: String) -> String?
    func set(_ value: Any?, forKey: String)
}

// Production implementations
class RealFileSystem: FileSystemProtocol {
    func fileExists(atPath: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

// Test implementations
class MockFileSystem: FileSystemProtocol {
    var mockFiles: Set<String> = []

    func fileExists(atPath: String) -> Bool {
        mockFiles.contains(path)
    }
}

// Inject dependencies
class SyncViewModel: ObservableObject {
    private let fileSystem: FileSystemProtocol
    private let userDefaults: UserDefaultsProtocol

    init(
        fileSystem: FileSystemProtocol = RealFileSystem(),
        userDefaults: UserDefaultsProtocol = UserDefaults.standard
    ) {
        self.fileSystem = fileSystem
        self.userDefaults = userDefaults
    }
}
```

**Benefits**:
- Easier unit testing
- More flexible architecture
- Better testability

**Files affected**:
- SyncViewModel.swift
- RsyncRunner.swift
- Test files

---

## 📊 Implementation Priority Matrix

### Quick Wins (Easy + High Impact)
1. **LG-1**: Interactive button modifiers
2. **LG-3**: Enhanced cancel button style
3. **A-1**: VoiceOver labels
4. **A-2**: Dynamic type support
5. **UX-6**: Enhanced keyboard shortcuts

### High Value (Medium-Hard + High Impact)
1. **RE-1**: Pre-flight checks
2. **RE-2**: Better error messages
3. **UX-2**: Connection testing
4. **UX-3**: Transfer estimates
5. **UX-4**: File count progress
6. **FE-2**: Exclude patterns
7. **FE-4**: Sync verification
8. **RE-3**: Network monitoring
9. **RE-4**: Retry logic
10. **CQ-1**: Unit tests
11. **CQ-2**: Separate sync service
12. **CQ-3**: Proper error types

### Nice to Have (P2-P3)
- All other enhancements

---

## 🎯 Suggested Roadmap

### Phase 1: Polish & Reliability (2-3 weeks)
Focus on making existing features solid and professional.

**Goals**:
- All Liquid Glass enhancements
- Pre-flight checks
- Better error handling
- Connection testing
- VoiceOver support

**Impact**: Professional polish, fewer failed syncs

---

### Phase 2: Enhanced UX (2-3 weeks)
Add features users have been missing.

**Goals**:
- Transfer estimates
- File count progress
- Exclude patterns
- Sync verification
- Better empty states
- Drag & drop folders

**Impact**: Better user experience, more flexibility

---

### Phase 3: Advanced Features (3-4 weeks)
Add power-user features.

**Goals**:
- Scheduled syncs
- Network monitoring
- Bandwidth statistics
- Sync groups
- Conflict resolution

**Impact**: Power users can do more complex workflows

---

### Phase 4: Code Quality (2 weeks)
Technical debt and testing.

**Goals**:
- Unit tests
- Separate sync service
- Async/await migration
- Dependency injection
- Error type refactoring

**Impact**: Easier to maintain and extend

---

## 📝 Notes

### Dependencies Between Enhancements
- **FE-4** (Sync verification) depends on **RE-2** (Better error parsing)
- **FE-3** (Two-way sync detection) depends on **FE-5** (Bandwidth statistics)
- **CQ-4** (Async/await) should be done before **CQ-2** (Separate service)
- **RE-3** (Network monitoring) works better with **RE-4** (Retry logic)

### Breaking Changes
None of these enhancements require breaking changes to existing functionality.

### Design Decisions to Consider
1. Should sync verification be automatic or opt-in? (Recommend opt-in for performance)
2. Should failed syncs auto-retry or require user confirmation? (Recommend auto-retry with option to disable)
3. Should multiple destinations sync sequentially or in parallel? (Recommend parallel with option)
4. Should exclude patterns be global or per-profile? (Recommend per-profile)

---

## 🤝 Contributing
When implementing these enhancements:
1. Create a new branch for each enhancement
2. Reference the enhancement ID in commit messages (e.g., "LG-1: Add interactive modifiers")
3. Update this document when completing enhancements
4. Add tests for new functionality
5. Update README.md if user-facing features change

---

*Last updated: 2025-12-05*
