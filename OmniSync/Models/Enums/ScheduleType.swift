import Foundation

enum ScheduleType: String, CaseIterable, Identifiable, Codable {
    case interval
    case daily
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .interval: return "Every X minutes"
        case .daily: return "Daily at specific time"
        case .weekly: return "Weekly on specific days"
        }
    }
}
