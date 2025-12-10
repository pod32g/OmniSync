import Foundation

enum ConflictResolution: String, CaseIterable, Identifiable {
    case keepLocal = "keep_local"
    case keepRemote = "keep_remote"
    case keepNewer = "keep_newer"
    case keepLarger = "keep_larger"
    case skip = "skip"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepLocal: return "Keep Local"
        case .keepRemote: return "Keep Remote"
        case .keepNewer: return "Keep Newer"
        case .keepLarger: return "Keep Larger"
        case .skip: return "Skip"
        }
    }
}
