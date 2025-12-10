import Foundation

enum PreflightCheckResult: Equatable {
    case pass
    case warning(String)
    case fail(String)

    var isPassing: Bool {
        if case .pass = self { return true }
        if case .warning = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .fail = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .pass: return nil
        case .warning(let msg): return msg
        case .fail(let msg): return msg
        }
    }
}
