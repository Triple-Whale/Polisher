import Cocoa
import Carbon

class GlobalHotKey {
    private let aiManager: AIManager
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let historyManager: HistoryManager
    private let clipboardManager = ClipboardManager()
    private let textReplacer = TextReplacer()
    private var hotKeyRef: EventHotKeyRef?
    private var replaceHotKeyRef: EventHotKeyRef?
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
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            switch hotKeyID.id {
            case 1:
                GlobalHotKey.instance?.handleHotKey()
            case 2:
                GlobalHotKey.instance?.handleReplaceHotKey()
            default:
                break
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)

        var clipboardHotKeyID = EventHotKeyID()
        clipboardHotKeyID.signature = OSType(0x504F4C53) // "POLS"
        clipboardHotKeyID.id = 1
        RegisterEventHotKey(settingsManager.hotKeyCode, settingsManager.hotKeyModifiers, clipboardHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        var replaceHotKeyID = EventHotKeyID()
        replaceHotKeyID.signature = OSType(0x504F4C53)
        replaceHotKeyID.id = 2
        RegisterEventHotKey(settingsManager.replaceHotKeyCode, settingsManager.replaceHotKeyModifiers, replaceHotKeyID, GetApplicationEventTarget(), 0, &replaceHotKeyRef)

        let shortcut = SettingsManager.shortcutString(keyCode: settingsManager.hotKeyCode, modifiers: settingsManager.hotKeyModifiers)
        let replaceShortcut = SettingsManager.shortcutString(keyCode: settingsManager.replaceHotKeyCode, modifiers: settingsManager.replaceHotKeyModifiers)
        log.log(.info, category: "HotKey", "Registered clipboard shortcut: \(shortcut)")
        log.log(.info, category: "HotKey", "Registered replace shortcut: \(replaceShortcut)")
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = replaceHotKeyRef {
            UnregisterEventHotKey(ref)
            replaceHotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    func reregister() {
        unregister()
        register()
        log.log(.info, category: "HotKey", "Shortcuts re-registered")
    }

    private func handleHotKey() {
        guard settingsManager.hotKeyEnabled else {
            log.log(.debug, category: "HotKey", "Hotkey disabled, ignoring")
            return
        }

        log.log(.info, category: "HotKey", "Clipboard shortcut triggered, reading clipboard...")

        guard let clipboardText = clipboardManager.getText(), !clipboardText.isEmpty else {
            log.log(.error, category: "Capture", "Clipboard is empty")
            notificationManager.restoreIcon()
            return
        }

        processText(clipboardText, mode: .clipboard)
    }

    private func handleReplaceHotKey() {
        guard settingsManager.replaceHotKeyEnabled else {
            log.log(.debug, category: "HotKey", "Replace hotkey disabled, ignoring")
            return
        }

        log.log(.info, category: "HotKey", "Replace shortcut triggered, capturing selected text...")

        guard let selectedText = textReplacer.captureSelectedText(), !selectedText.isEmpty else {
            log.log(.error, category: "Capture", "No text selected")
            notificationManager.restoreIcon()
            return
        }

        processText(selectedText, mode: .replace)
    }

    private enum ProcessingMode {
        case clipboard
        case replace
    }

    private func processText(_ text: String, mode: ProcessingMode) {
        let charCount = text.count
        let preview = String(text.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        log.log(.info, category: "Capture", "Read \(charCount) chars: \"\(preview)\(charCount > 80 ? "..." : "")\"")

        let provider = settingsManager.selectedProvider.rawValue
        let model = settingsManager.selectedModel
        log.log(.info, category: "API", "Sending to \(provider) (\(model))...")

        notificationManager.setLoadingIcon()

        let history = historyManager
        let startTime = Date()

        Task {
            do {
                let improved = try await aiManager.improveText(text)
                let elapsed = String(format: "%.1fs", Date().timeIntervalSince(startTime))
                log.log(.success, category: "API", "Response received in \(elapsed) (\(improved.count) chars)")

                await MainActor.run {
                    history.addEntry(original: text, improved: improved)

                    switch mode {
                    case .clipboard:
                        clipboardManager.setText(improved)
                        log.log(.success, category: "Output", "Copied to clipboard (\(improved.count) chars)")
                    case .replace:
                        textReplacer.replaceSelectedText(with: improved)
                        log.log(.success, category: "Output", "Replaced selected text (\(improved.count) chars)")
                    }

                    notificationManager.restoreIcon()
                }
            } catch {
                let elapsed = String(format: "%.1fs", Date().timeIntervalSince(startTime))
                log.log(.error, category: "API", "Failed after \(elapsed): \(error.localizedDescription)")
                await MainActor.run {
                    notificationManager.restoreIcon()
                }
            }
        }
    }
}
