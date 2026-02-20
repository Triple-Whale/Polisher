import Cocoa

class ClipboardManager {
    private var savedContents: [NSPasteboard.PasteboardType: Data] = [:]
    private let pasteboard = NSPasteboard.general

    func save() {
        savedContents.removeAll()
        guard let items = pasteboard.pasteboardItems else { return }

        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    savedContents[type] = data
                }
            }
        }
    }

    func restore() {
        guard !savedContents.isEmpty else { return }

        pasteboard.clearContents()
        let item = NSPasteboardItem()
        for (type, data) in savedContents {
            item.setData(data, forType: type)
        }
        pasteboard.writeObjects([item])
        savedContents.removeAll()
    }

    func getText() -> String? {
        return pasteboard.string(forType: .string)
    }

    func setText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
