import Cocoa
import Carbon

class GlobalHotKey {
    private let aiManager: AIManager
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let textReplacer = TextReplacer()
    private let clipboardManager = ClipboardManager()
    private var hotKeyRef: EventHotKeyRef?
    private static var instance: GlobalHotKey?

    init(aiManager: AIManager, settingsManager: SettingsManager, notificationManager: NotificationManager) {
        self.aiManager = aiManager
        self.settingsManager = settingsManager
        self.notificationManager = notificationManager
        GlobalHotKey.instance = self
    }

    func register() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x504F4C53) // "POLS"
        hotKeyID.id = 1

        // Cmd+Option+I: keyCode 34 = 'i', modifiers = cmdKey + optionKey
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = 34

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            GlobalHotKey.instance?.handleHotKey()
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func handleHotKey() {
        guard settingsManager.hotKeyEnabled else { return }

        guard let selectedText = textReplacer.captureSelectedText(), !selectedText.isEmpty else {
            notificationManager.sendNotification(title: "Polisher", body: "No text selected")
            return
        }

        Task {
            do {
                let improved = try await aiManager.improveText(selectedText)

                await MainActor.run {
                    if settingsManager.autoReplace {
                        textReplacer.replaceSelectedText(with: improved)
                    } else {
                        clipboardManager.setText(improved)
                        notificationManager.notifySuccess(
                            originalLength: selectedText.count,
                            improvedLength: improved.count
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    notificationManager.notifyError(error)
                }
            }
        }
    }
}
