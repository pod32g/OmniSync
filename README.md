# OmniSync (macOS)

SwiftUI macOS app to push local folders to a NAS over rsync/SSH.

## Features
- Collects host, username, password (sshpass) or key/agent auth.
- Push-only sync: local → NAS using `rsync -avz --progress --delete`.
- Auto-sync with configurable interval.
- File filters (videos/photos/docs/audio/archives/custom patterns).
- Native folder picker for local source.
- Menu bar extra with quick controls.
- Quiet mode to reduce UI churn; full logs saved to a temp file and mirrored to stdout.
- Cancel in-flight sync; progress bar throttled for smoother UI.
- Dock icon hidden (runs as accessory with menu bar extra).

## Requirements
- macOS 14+ (project targets 14.0).
- rsync available on the system (macOS ships it).
- Optional: `sshpass` (e.g., `/opt/homebrew/bin/sshpass`) for password auth; otherwise use SSH keys/agent.

## Run
1) Open `OmniSync.xcodeproj` in Xcode 15+ (macOS SDK 14+).
2) Build & run the `OmniSync` scheme (macOS).
3) Fill Host, Username, Password (or leave blank to use key/agent), Remote path, and Local source (use “Choose…”).
4) (Optional) Pick filters and enable Auto Sync.
5) Click “Sync Now” (header button).

## Logs
- Live rsync stdout/stderr is mirrored to stdout (visible in Console/profiler when launched from Xcode/Terminal).
- Temp log file: `NSTemporaryDirectory()/omnisync.log` (use “Show Log File” in the Output card).
- Quiet mode hides live logs in the UI but still writes to the file/stdout.

## Notes
- `StrictHostKeyChecking` is disabled to avoid prompts; a temp known_hosts is used.
- With no password, SSH runs in `BatchMode=yes` to fail fast if no key/agent is available.
- `--delete` removes files on the NAS that are absent locally; remove it if you don’t want deletions.
