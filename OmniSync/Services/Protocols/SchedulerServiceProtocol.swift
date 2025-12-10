import Foundation

protocol SchedulerServiceProtocol {
    func startSchedule(_ schedule: SyncSchedule, onTrigger: @escaping () -> Void)
    func stopSchedule()
    func calculateNextRunDate(for schedule: SyncSchedule) -> Date?
}
