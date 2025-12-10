import Foundation

enum SyncDirection: String, CaseIterable, Identifiable, Codable {
    case push
    case pull

    var id: String { rawValue }

    var label: String {
        switch self {
        case .push: return "Push (local → remote)"
        case .pull: return "Pull (remote → local)"
        }
    }
}
