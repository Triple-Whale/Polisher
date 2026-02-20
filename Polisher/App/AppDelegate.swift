import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController!
    let settingsManager = SettingsManager()
    let aiManager = AIManager()
    let notificationManager = NotificationManager()
    var servicesProvider: ServicesProvider!
    var globalHotKey: GlobalHotKey!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        servicesProvider = ServicesProvider(
            aiManager: aiManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager
        )

        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()

        menuBarController = MenuBarController(
            settingsManager: settingsManager,
            aiManager: aiManager
        )

        globalHotKey = GlobalHotKey(
            aiManager: aiManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager
        )
        globalHotKey.register()

        let detector = APIKeyDetector()
        if settingsManager.claudeAPIKey.isEmpty, let key = detector.detectClaudeKey() {
            settingsManager.claudeAPIKey = key
        }
        if settingsManager.openAIAPIKey.isEmpty, let key = detector.detectOpenAIKey() {
            settingsManager.openAIAPIKey = key
        }

        aiManager.configure(with: settingsManager)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        SystemPromptManager.shared.refreshIfNeeded()
    }
}
