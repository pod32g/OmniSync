import Foundation

protocol NetworkServiceProtocol {
    var networkStatus: NetworkStatus { get }

    func startMonitoring(onStatusChanged: @escaping (NetworkStatus) -> Void)
    func stopMonitoring()
}
