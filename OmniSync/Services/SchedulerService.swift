import Foundation

final class SchedulerService: SchedulerServiceProtocol {
    private var timer: Timer?

    func startSchedule(_ schedule: SyncSchedule, onTrigger: @escaping () -> Void) {
        stopSchedule()

        guard let nextRun = calculateNextRunDate(for: schedule) else {
            return
        }

        let interval = nextRun.timeIntervalSinceNow
        guard interval > 0 else {
            // Next run is now or in the past, run immediately and reschedule
            DispatchQueue.main.async {
                onTrigger()
                self.startSchedule(schedule, onTrigger: onTrigger)
            }
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                onTrigger()
                self?.startSchedule(schedule, onTrigger: onTrigger)
            }
        }
    }

    func stopSchedule() {
        timer?.invalidate()
        timer = nil
    }

    func calculateNextRunDate(for schedule: SyncSchedule) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch schedule.type {
        case .interval:
            return calendar.date(byAdding: .minute, value: schedule.intervalMinutes, to: now)

        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: schedule.dailyTime)
            guard let hour = components.hour, let minute = components.minute else { return nil }

            var nextRun = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
            if nextRun <= now {
                nextRun = calendar.date(byAdding: .day, value: 1, to: nextRun) ?? now
            }
            return nextRun

        case .weekly:
            guard !schedule.weeklyDays.isEmpty else { return nil }

            let components = calendar.dateComponents([.hour, .minute], from: schedule.weeklyTime)
            guard let hour = components.hour, let minute = components.minute else { return nil }

            let currentWeekday = calendar.component(.weekday, from: now)
            let sortedDays = schedule.weeklyDays.map { $0.rawValue }.sorted()

            // Find next scheduled day
            var nextDay: Int?
            for day in sortedDays {
                if day > currentWeekday {
                    nextDay = day
                    break
                } else if day == currentWeekday {
                    // Check if time hasn't passed yet today
                    if let todayRun = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now),
                       todayRun > now {
                        nextDay = day
                        break
                    }
                }
            }

            // If no day found this week, use first day of next week
            if nextDay == nil {
                nextDay = sortedDays.first
            }

            guard let targetWeekday = nextDay else { return nil }

            // Calculate days to add
            var daysToAdd = targetWeekday - currentWeekday
            if daysToAdd <= 0 {
                daysToAdd += 7
            }

            var nextRun = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
            nextRun = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: nextRun) ?? nextRun

            return nextRun
        }
    }
}
