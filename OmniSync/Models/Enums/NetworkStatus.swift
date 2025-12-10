import Foundation

enum NetworkStatus: Equatable {
    case connected
    case disconnected
    case unknown

    var isConnected: Bool {
        self == .connected
    }

    var label: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .unknown: return "Unknown"
        }
    }
}
