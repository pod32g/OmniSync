import Foundation
import Network

final class NetworkMonitorService: NetworkServiceProtocol {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.omnisync.networkmonitor")
    private(set) var networkStatus: NetworkStatus = .unknown
    private var onStatusChanged: ((NetworkStatus) -> Void)?

    func startMonitoring(onStatusChanged: @escaping (NetworkStatus) -> Void) {
        self.onStatusChanged = onStatusChanged
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newStatus: NetworkStatus = path.status == .satisfied ? .connected : .disconnected

            // Only notify if status changed
            if newStatus != self.networkStatus {
                self.networkStatus = newStatus
                self.onStatusChanged?(newStatus)
            }
        }
        monitor?.start(queue: queue)
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        networkStatus = .unknown
    }
}
