import Foundation

struct PreflightChecks {
    let localPathExists: PreflightCheckResult
    let diskSpace: PreflightCheckResult
    let networkConnection: PreflightCheckResult

    var canProceed: Bool {
        !localPathExists.isFailure && !diskSpace.isFailure && !networkConnection.isFailure
    }

    var hasWarnings: Bool {
        if case .warning = localPathExists { return true }
        if case .warning = diskSpace { return true }
        if case .warning = networkConnection { return true }
        return false
    }

    var allResults: [PreflightCheckResult] {
        [localPathExists, diskSpace, networkConnection]
    }
}
