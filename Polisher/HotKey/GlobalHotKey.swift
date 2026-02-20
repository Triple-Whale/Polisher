import Cocoa
import Carbon

class GlobalHotKey {
    private let aiManager: AIManager
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let historyManager: HistoryManager
    private let textReplacer = TextReplacer()
    private let clipboardManager = ClipboardManager()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private static var instance: GlobalHotKey?
    private let log = LogManager.shared

    init(aiManager: AIManager, settingsManager: SettingsManager, notificationManager: NotificationManager, historyManager: HistoryManager) {
        self.aiManager = aiManager
        self.settingsManager = settingsManager
        self.notificationManager = notificationManager
        self.historyManager = historyManager
        GlobalHotKey.instance = self
    }

    func register() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x504F4C53) // "POLS"
        hotKeyID.id = 1

        let modifiers = settingsManager.hotKeyModifiers
        let keyCode = settingsManager.hotKeyCode

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            GlobalHotKey.instance?.handleHotKey()
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        let shortcut = SettingsManager.shortcutString(keyCode: keyCode, modifiers: modifiers)
        log.log(.info, category: "HotKey", "Registered shortcut: \(shortcut)")
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    func reregister() {
        unregister()
        register()
        log.log(.info, category: "HotKey", "Shortcut re-registered")
    }

    private func handleHotKey() {
        guard settingsManager.hotKeyEnabled else {
            log.log(.debug, category: "HotKey", "Hotkey disabled, ignoring")
            return
        }

        log.log(.info, category: "HotKey", "Shortcut triggered, capturing text...")

        guard let selectedText = textReplacer.captureSelectedText(), !selectedText.isEmpty else {
            log.log(.error, category: "Capture", "No text selected")
            notificationManager.showMenuBarMessage("No text selected")
            return
        }

        let charCount = selectedText.count
        let preview = String(selectedText.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        log.log(.info, category: "Capture", "Captured \(charCount) chars: \"\(preview)\(charCount > 80 ? "..." : "")\"")

        let provider = settingsManager.selectedProvider.rawValue
        let model = settingsManager.selectedModel
        log.log(.info, category: "API", "Sending to \(provider) (\(model))...")

        let history = historyManager
        let startTime = Date()

        Task {
            do {
                let improved = try await aiManager.improveText(selectedText)
                let elapsed = String(format: "%.1fs", Date().timeIntervalSince(startTime))
                log.log(.success, category: "API", "Response received in \(elapsed) (\(improved.count) chars)")

                await MainActor.run {
                    history.addEntry(original: selectedText, improved: improved)
                    log.log(.debug, category: "History", "Entry saved")

                    if settingsManager.autoReplace {
                        textReplacer.replaceSelectedText(with: improved)
                        log.log(.success, category: "Output", "Text replaced in-place")
                        notificationManager.showMenuBarMessage("Text replaced!")
                    } else {
                        clipboardManager.setText(improved)
                        log.log(.success, category: "Output", "Copied to clipboard (\(improved.count) chars)")
                        notificationManager.showMenuBarMessage("Copied to clipboard!")
                    }
                }
            } catch {
                let elapsed = String(format: "%.1fs", Date().timeIntervalSince(startTime))
                log.log(.error, category: "API", "Failed after \(elapsed): \(error.localizedDescription)")
                await MainActor.run {
                    notificationManager.showMenuBarMessage("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
