import Foundation

/// Dependency Injection container for the app
/// Responsible for creating and providing all services, repositories, and view models
final class AppDependencyContainer {
    // MARK: - Services

    lazy var rsyncService: RsyncServiceProtocol = {
        RsyncService()
    }()

    lazy var networkService: NetworkServiceProtocol = {
        NetworkMonitorService()
    }()

    lazy var persistenceService: PersistenceServiceProtocol = {
        PersistenceService()
    }()

    lazy var notificationService: NotificationServiceProtocol = {
        NotificationService()
    }()

    lazy var schedulerService: SchedulerServiceProtocol = {
        SchedulerService()
    }()

    // MARK: - Repositories

    lazy var profileRepository: ProfileRepository = {
        ProfileRepository(persistenceService: persistenceService)
    }()

    lazy var historyRepository: HistoryRepository = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("OmniSync", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let historyFileURL = folder.appendingPathComponent("history.json")
        return HistoryRepository(fileURL: historyFileURL, maxEntries: 50)
    }()

    lazy var groupRepository: GroupRepository = {
        GroupRepository(persistenceService: persistenceService)
    }()

    // MARK: - View Models

    func makeSyncViewModel() -> SyncViewModel {
        SyncViewModel(
            rsyncService: rsyncService,
            networkService: networkService,
            persistenceService: persistenceService,
            notificationService: notificationService,
            schedulerService: schedulerService,
            profileRepository: profileRepository,
            historyRepository: historyRepository,
            groupRepository: groupRepository
        )
    }
}
