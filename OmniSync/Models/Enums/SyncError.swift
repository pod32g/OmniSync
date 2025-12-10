import Foundation

enum SyncError: LocalizedError, Equatable {
    case authenticationFailed
    case networkUnreachable(String)
    case permissionDenied(path: String)
    case diskFull
    case pathNotFound(path: String)
    case hostKeyChanged
    case rsyncNotFound
    case timeout
    case cancelled
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Check your username and password."
        case .networkUnreachable(let host):
            return "Cannot reach the remote host '\(host)'. Check your network connection."
        case .permissionDenied(let path):
            return "Permission denied for: \(path)"
        case .diskFull:
            return "Not enough disk space on the destination."
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .hostKeyChanged:
            return "Host key verification failed. The remote host's key has changed."
        case .rsyncNotFound:
            return "rsync command not found. Please install rsync."
        case .timeout:
            return "Connection timed out. The remote host is not responding."
        case .cancelled:
            return "Sync was cancelled."
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "Try using SSH keys instead of password, or verify your credentials are correct."
        case .networkUnreachable:
            return "Make sure you're connected to the network and the host is reachable. Try running 'Test Connection' first."
        case .permissionDenied:
            return "Check file permissions on the remote system. You may need to change ownership or permissions."
        case .diskFull:
            return "Free up space on the destination drive or choose a different destination."
        case .pathNotFound:
            return "Verify the path exists and is typed correctly. The path might have been moved or deleted."
        case .hostKeyChanged:
            return "Remove the old key from ~/.ssh/known_hosts or disable strict host key checking in settings."
        case .rsyncNotFound:
            return "Install rsync using Homebrew: brew install rsync"
        case .timeout:
            return "Check your network connection and try again. The remote server might be down or unreachable."
        case .cancelled:
            return nil
        case .unknown:
            return "Check the sync logs for more details. If the problem persists, report this issue."
        }
    }

    static func parse(from output: String) -> SyncError {
        let lowercased = output.lowercased()

        if lowercased.contains("command not found") && lowercased.contains("rsync") {
            return .rsyncNotFound
        } else if lowercased.contains("permission denied") {
            // Try to extract path from error
            if let pathMatch = output.range(of: #"([/~][^\s:]+)"#, options: .regularExpression) {
                let path = String(output[pathMatch])
                return .permissionDenied(path: path)
            }
            return .permissionDenied(path: "unknown")
        } else if lowercased.contains("no route to host") || lowercased.contains("connection refused") {
            // Extract host if possible
            if let hostMatch = output.range(of: #"@([^\s:]+)"#, options: .regularExpression) {
                let host = String(output[hostMatch]).replacingOccurrences(of: "@", with: "")
                return .networkUnreachable(host)
            }
            return .networkUnreachable("unknown")
        } else if lowercased.contains("authentication failed") || lowercased.contains("permission denied (publickey") || lowercased.contains("password:") {
            return .authenticationFailed
        } else if lowercased.contains("no space left on device") || lowercased.contains("disk quota exceeded") {
            return .diskFull
        } else if lowercased.contains("no such file or directory") {
            // Try to extract path
            if let pathMatch = output.range(of: #"([/~][^\s:]+)"#, options: .regularExpression) {
                let path = String(output[pathMatch])
                return .pathNotFound(path: path)
            }
            return .pathNotFound(path: "unknown")
        } else if lowercased.contains("host key") && (lowercased.contains("changed") || lowercased.contains("verification failed")) {
            return .hostKeyChanged
        } else if lowercased.contains("connection timed out") || lowercased.contains("operation timed out") {
            return .timeout
        }

        return .unknown(message: String(output.prefix(200)))
    }
}
