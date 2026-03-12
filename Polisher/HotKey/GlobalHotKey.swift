import Cocoa
import Carbon

class GlobalHotKey {
    private let aiManager: AIManager
    private let settingsManager: SettingsManager
    private let notificationManager: NotificationManager
    private let historyManager: HistoryManager
    private let textReplacer = TextReplacer()
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

            LogManager.shared.log(.debug, category: "HotKey", "Event received, id=\(hotKeyID.id), sig=\(hotKeyID.signature)")

            if hotKeyID.id == 2 {
                GlobalHotKey.instance?.handleReplaceHotKey()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)

        var replaceHotKeyID = EventHotKeyID()
        replaceHotKeyID.signature = OSType(0x504F4C52) // "POLR"
        replaceHotKeyID.id = 2
        let replaceStatus = RegisterEventHotKey(settingsManager.replaceHotKeyCode, settingsManager.replaceHotKeyModifiers, replaceHotKeyID, GetApplicationEventTarget(), 0, &replaceHotKeyRef)
        log.log(.debug, category: "HotKey", "Replace registration status: \(replaceStatus), keyCode: \(settingsManager.replaceHotKeyCode), modifiers: \(settingsManager.replaceHotKeyModifiers)")

        let replaceShortcut = SettingsManager.shortcutString(keyCode: settingsManager.replaceHotKeyCode, modifiers: settingsManager.replaceHotKeyModifiers)
        log.log(.info, category: "HotKey", "Registered replace shortcut: \(replaceShortcut)")
    }

    func unregister() {
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

    private func handleReplaceHotKey() {
        guard Self.checkAccessibility() else { return }

        log.log(.info, category: "HotKey", "Replace shortcut triggered, capturing selected text...")

        guard let selectedText = textReplacer.captureSelectedText(), !selectedText.isEmpty else {
            log.log(.error, category: "Capture", "No text selected")
            notificationManager.restoreIcon()
            return
        }

        processText(selectedText)
    }

    private static func checkAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions(
            [key: true] as CFDictionary
        )
        if !trusted {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Polisher needs Accessibility access to capture and replace selected text.\n\n1. Open System Settings > Privacy & Security > Accessibility\n2. Enable Polisher in the list\n3. Try the shortcut again"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            LogManager.shared.log(.error, category: "Access", "Accessibility permission not granted")
        }
        return trusted
    }

    private func processText(_ text: String) {
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
                let elapsedSeconds = Date().timeIntervalSince(startTime)
                log.log(.success, category: "API", "Response received in \(elapsed) (\(improved.count) chars)")

                await MainActor.run {
                    history.addEntry(original: text, improved: improved)
                    StatsManager.shared.recordPolish(
                        inputChars: text.count,
                        outputChars: improved.count,
                        elapsedSeconds: elapsedSeconds,
                        provider: provider,
                        model: model
                    )

                    textReplacer.replaceSelectedText(with: improved)
                    log.log(.success, category: "Output", "Replaced selected text (\(improved.count) chars)")

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
