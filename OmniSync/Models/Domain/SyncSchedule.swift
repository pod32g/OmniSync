import Foundation

struct SyncSchedule: Codable, Equatable {
    var enabled: Bool
    var type: ScheduleType
    var intervalMinutes: Int
    var dailyTime: Date
    var weeklyDays: Set<Weekday>
    var weeklyTime: Date

    static var `default`: SyncSchedule {
        SyncSchedule(
            enabled: false,
            type: .interval,
            intervalMinutes: 30,
            dailyTime: Calendar.current.date(from: DateComponents(hour: 2, minute: 0)) ?? Date(),
            weeklyDays: [.monday, .friday],
            weeklyTime: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        )
    }
}
