import Cocoa

class ClipboardManager {
    private var savedContents: [[NSPasteboard.PasteboardType: Data]]?
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func save() {
        savedContents = (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    contents[type] = data
                }
            }
            return contents
        }
    }

    func restore(ifUnchangedSince changeCount: Int) {
        guard let savedContents else { return }
        self.savedContents = nil
        guard pasteboard.changeCount == changeCount else { return }

        pasteboard.clearContents()
        let items = savedContents.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    func clear() {
        pasteboard.clearContents()
    }

    func getText() -> String? {
        return pasteboard.string(forType: .string)
    }

    func setText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
