import Cocoa

@main
struct TextCaptureTests {
    @MainActor
    static func main() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let clipboard = ClipboardManager(pasteboard: pasteboard)
        let stalePrompt = "Fix grammar and spelling. Return only the improved text."

        clipboard.setText(stalePrompt)
        let failedCopy = TextReplacer(clipboardManager: clipboard, readSelection: { nil }, copySelection: {})
        let missingText = await failedCopy.captureSelectedText()
        expect(missingText == nil, "A failed copy must never return the old system prompt")
        expect(clipboard.getText() == stalePrompt, "Failed capture must restore the clipboard")

        let delayedCopy = TextReplacer(clipboardManager: clipboard, readSelection: { nil }, copySelection: {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                clipboard.setText("This are the selected sentence.")
            }
        })
        let capturedText = await delayedCopy.captureSelectedText()
        expect(capturedText == "This are the selected sentence.", "Copy must tolerate delays beyond 150 ms")
        expect(clipboard.getText() == stalePrompt, "Successful capture must restore the clipboard")

        let repeatedCopy = TextReplacer(clipboardManager: clipboard, readSelection: { nil }, copySelection: {
            clipboard.setText(stalePrompt)
        })
        let repeatedText = await repeatedCopy.captureSelectedText()
        expect(repeatedText == stalePrompt, "A fresh copy is valid even when its text matches the old clipboard")

        var copyCalled = false
        let accessibleSelection = TextReplacer(clipboardManager: clipboard, readSelection: { "Selected text" }, copySelection: {
            copyCalled = true
        })
        let accessibleText = await accessibleSelection.captureSelectedText()
        expect(accessibleText == "Selected text" && !copyCalled, "Accessibility selection should bypass copying")
        expect(clipboard.getText() == stalePrompt, "Accessibility capture must leave the clipboard alone")

        copyCalled = false
        let canvasEditor = TextReplacer(clipboardManager: clipboard, readSelection: { nil }, copySelection: {
            copyCalled = true
            clipboard.setText("Need to work on ore ownership cross team")
        })
        let canvasText = await canvasEditor.captureSelectedText()
        expect(copyCalled && canvasText == "Need to work on ore ownership cross team", "Missing accessibility selection must fall back to copying")
        expect(clipboard.getText() == stalePrompt, "Copy fallback must restore the clipboard")

        let blankCopy = TextReplacer(clipboardManager: clipboard, readSelection: { nil }, copySelection: {
            clipboard.setText(" \n\t")
        })
        let blankText = await blankCopy.captureSelectedText()
        expect(blankText == nil, "A blank copied selection must count as no selection")

        clipboard.clear()
        let initiallyEmpty = await delayedCopy.captureSelectedText()
        expect(initiallyEmpty != nil && clipboard.getText() == nil, "An initially empty clipboard must remain empty")

        let first = NSPasteboardItem()
        first.setString("First item", forType: .string)
        first.setData(Data("<b>First item</b>".utf8), forType: .html)
        let second = NSPasteboardItem()
        second.setString("Second item", forType: .string)
        pasteboard.writeObjects([first, second])
        clipboard.save()
        clipboard.setText("Polished result")
        clipboard.restore(ifUnchangedSince: clipboard.changeCount)
        expect(pasteboard.pasteboardItems?.count == 2, "Restoration must preserve every clipboard item")
        expect(pasteboard.pasteboardItems?.first?.data(forType: .html) == Data("<b>First item</b>".utf8), "Restoration must preserve rich formats")

        clipboard.save()
        clipboard.setText("Polished result")
        let ownedChangeCount = clipboard.changeCount
        clipboard.setText("New user copy")
        clipboard.restore(ifUnchangedSince: ownedChangeCount)
        expect(clipboard.getText() == "New user copy", "Restoration must not overwrite a newer user copy")

        print("Text capture and clipboard regression tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
