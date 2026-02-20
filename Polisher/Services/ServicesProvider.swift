import Cocoa

class ServicesProvider: NSObject {
    private let aiManager: AIManager
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let clipboardManager = ClipboardManager()
    private let textReplacer = TextReplacer()

    init(aiManager: AIManager, settingsManager: SettingsManager, notificationManager: NotificationManager) {
        self.aiManager = aiManager
        self.settingsManager = settingsManager
        self.notificationManager = notificationManager
    }

    @objc func improveText(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No text selected" as NSString
            return
        }

        let autoReplace = settingsManager.autoReplace
        let clipboard = clipboardManager
        let notifications = notificationManager
        let ai = aiManager

        Task { @MainActor in
            do {
                let improved = try await ai.improveText(text)

                if autoReplace {
                    pboard.clearContents()
                    pboard.setString(improved, forType: .string)
                } else {
                    clipboard.setText(improved)
                    notifications.notifySuccess(
                        originalLength: text.count,
                        improvedLength: improved.count
                    )
                }
            } catch {
                notifications.notifyError(error)
            }
        }
    }
}
