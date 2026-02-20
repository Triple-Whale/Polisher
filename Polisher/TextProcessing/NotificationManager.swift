import UserNotifications

class NotificationManager {
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func notifySuccess(originalLength: Int, improvedLength: Int) {
        sendNotification(
            title: "Text Improved",
            body: "Improved text copied to clipboard (\(originalLength) -> \(improvedLength) chars)"
        )
    }

    func notifyError(_ error: Error) {
        sendNotification(
            title: "Polisher Error",
            body: error.localizedDescription
        )
    }
}
