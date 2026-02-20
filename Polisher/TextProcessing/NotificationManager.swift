import Cocoa
import UserNotifications

class NotificationManager {
    func sendNotification(title: String, body: String) {
        showMenuBarMessage(body)
    }

    func notifySuccess(originalLength: Int, improvedLength: Int) {
        showMenuBarMessage("Copied to clipboard! (\(originalLength) -> \(improvedLength) chars)")
    }

    func notifyError(_ error: Error) {
        showMenuBarMessage("Error: \(error.localizedDescription)", duration: 5.0)
    }

    func showMenuBarMessage(_ message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            guard let appDelegate = NSApp.delegate as? AppDelegate,
                  let button = appDelegate.statusItem?.button else { return }

            button.title = " \(message)"

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                button.title = ""
            }
        }
    }
}
