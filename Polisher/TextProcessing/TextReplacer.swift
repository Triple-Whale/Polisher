import Cocoa
import Carbon

class TextReplacer {
    private let clipboardManager: ClipboardManager
    private let readSelection: () -> String?
    private let copySelection: () -> Void

    init(
        clipboardManager: ClipboardManager = ClipboardManager(),
        readSelection: @escaping () -> String? = TextReplacer.accessibilitySelection,
        copySelection: @escaping () -> Void = { TextReplacer.simulateKeyPress(keyCode: 8, flags: .maskCommand) }
    ) {
        self.clipboardManager = clipboardManager
        self.readSelection = readSelection
        self.copySelection = copySelection
    }

    @MainActor
    func captureSelectedText() async -> String? {
        if let text = readSelection() {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        }

        clipboardManager.save()
        clipboardManager.clear()
        let emptyChangeCount = clipboardManager.changeCount
        var restoreChangeCount = emptyChangeCount
        defer { clipboardManager.restore(ifUnchangedSince: restoreChangeCount) }
        copySelection()

        for _ in 0..<40 {
            guard !Task.isCancelled else { return nil }
            if clipboardManager.changeCount != emptyChangeCount,
               let text = clipboardManager.getText() {
                restoreChangeCount = clipboardManager.changeCount
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return nil
    }

    @MainActor
    func replaceSelectedText(with newText: String) async {
        clipboardManager.save()
        clipboardManager.setText(newText)
        let pasteChangeCount = clipboardManager.changeCount
        Self.simulateKeyPress(keyCode: 9, flags: .maskCommand)
        try? await Task.sleep(nanoseconds: 500_000_000)
        clipboardManager.restore(ifUnchangedSince: pasteChangeCount)
    }

    static func accessibilitySelection() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success else {
            return nil
        }
        return selected as? String
    }

    private static func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .privateState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
