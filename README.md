# OmniSync (macOS)

SwiftUI macOS app to push local folders to a NAS over rsync/SSH. Built with Apple's Liquid Glass design system.

## Features
- Collects host, username, password (sshpass) or key/agent auth.
- Push or pull sync: local ↔ NAS using `rsync -av --progress` with optional delete.
- LAN speed toggle to disable compression, force whole-file copies, and pick a fast cipher.
- Auto-sync with configurable interval.
- Dry-run mode to preview actions.
- Bandwidth cap and resume partial transfers.
- File filters (videos/photos/docs/audio/archives/custom patterns).
- Native folder picker for local source.
- Saved profiles to quickly swap hosts/paths/filters.
- Optional notifications when a sync finishes.
- Menu bar extra with quick controls.
- Quiet mode to reduce UI churn; full logs saved to a temp file and mirrored to stdout.
- Cancel in-flight sync; progress bar throttled for smoother UI.
- Dock icon hidden (runs as accessory with menu bar extra).

## Design

OmniSync follows Apple's Liquid Glass design guidelines introduced in macOS 26:
- **Content-first hierarchy**: Glass materials enhance content rather than competing with it
- **Responsive interaction**: Controls feel alive with adaptive colors and fluid motion
- **Consistent visual language**: Unified design across macOS with capsule shapes and floating elements
- **Native SwiftUI APIs**: Uses `.glassEffect()`, `.glassProminent`, and `GlassEffectContainer` from macOS 26 SDK

## Requirements
- macOS 26+ (macOS Tahoe or later)
- Xcode 16+ with macOS 26 SDK
- rsync available on the system (macOS ships it)
- Optional: `sshpass` (e.g., `/opt/homebrew/bin/sshpass`) for password auth; otherwise use SSH keys/agent

## Run
1) Open `OmniSync.xcodeproj` in Xcode 16+ (macOS SDK 26+).
2) Build & run the `OmniSync` scheme (macOS).
3) Fill Host, Username, Password (or leave blank to use key/agent), Remote path, and Local source (use "Choose…").
4) (Optional) Pick filters and enable Auto Sync.
5) Click "Sync Now" (header button).

## Logs
- Live rsync stdout/stderr is mirrored to stdout (visible in Console/profiler when launched from Xcode/Terminal).
- Temp log file: `NSTemporaryDirectory()/omnisync.log` (use “Show Log File” in the Output card).
- Quiet mode hides live logs in the UI but still writes to the file/stdout.

## Roadmap

See [ENHANCEMENTS.md](ENHANCEMENTS.md) for a detailed roadmap of planned features and improvements, including:
- 🎨 Enhanced Liquid Glass features (interactive modifiers, transitions)
- ✨ UX improvements (drag & drop, connection testing, transfer estimates)
- 🚀 New features (scheduled syncs, exclude patterns, sync verification)
- 🛡️ Better reliability (pre-flight checks, error handling, network monitoring)
- ♿ Accessibility improvements (VoiceOver, keyboard navigation)
- 🏗️ Code quality enhancements (tests, proper error types, async/await)

## Notes
- `StrictHostKeyChecking` is disabled to avoid prompts; a temp known_hosts is used.
- With no password, SSH runs in `BatchMode=yes` to fail fast if no key/agent is available.
- Deletion is off by default; enable "Delete remote files to match source" only if you want the NAS pruned.
- For faster LAN transfers, toggle "Optimize for LAN speed" to disable compression, use whole-file copies, and select a fast cipher.
