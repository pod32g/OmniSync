import Foundation

protocol NotificationServiceProtocol {
    func requestPermission()
    func sendNotification(title: String, body: String)
}
