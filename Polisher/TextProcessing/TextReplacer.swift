import Cocoa
import Carbon

class TextReplacer {
    private let clipboardManager = ClipboardManager()

    func captureSelectedText() -> String? {
        clipboardManager.save()
        simulateCopy()
        usleep(150_000) // 150ms for clipboard to populate
        let text = clipboardManager.getText()
        return text
    }

    func replaceSelectedText(with newText: String, restoreClipboard: Bool = true) {
        clipboardManager.setText(newText)
        simulatePaste()

        if restoreClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.clipboardManager.restore()
            }
        }
    }

    private func simulateCopy() {
        simulateKeyPress(keyCode: 8, flags: .maskCommand) // Cmd+C
    }

    private func simulatePaste() {
        simulateKeyPress(keyCode: 9, flags: .maskCommand) // Cmd+V
    }

    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

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
