import Foundation

enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case success(String)
    case failed(String)
}
