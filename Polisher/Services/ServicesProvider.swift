import Cocoa

class ServicesProvider: NSObject {
    private let aiManager: AIManager
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let historyManager: HistoryManager
    private let clipboardManager = ClipboardManager()

    init(aiManager: AIManager, settingsManager: SettingsManager, notificationManager: NotificationManager, historyManager: HistoryManager) {
        self.aiManager = aiManager
        self.settingsManager = settingsManager
        self.notificationManager = notificationManager
        self.historyManager = historyManager
    }

    @objc func improveText(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No text on clipboard" as NSString
            return
        }

        let notifications = notificationManager
        let ai = aiManager
        let history = historyManager
        let clipboard = clipboardManager

        Task { @MainActor in
            do {
                let improved = try await ai.improveText(text)
                history.addEntry(original: text, improved: improved)
                clipboard.setText(improved)
                notifications.showMenuBarMessage("Done! Paste to use.")
            } catch {
                notifications.showMenuBarMessage("Error: \(error.localizedDescription)")
            }
        }
    }
}
