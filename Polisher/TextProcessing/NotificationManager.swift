import Cocoa

class NotificationManager {
    func setLoadingIcon() {
        DispatchQueue.main.async {
            guard let button = (NSApp.delegate as? AppDelegate)?.statusItem?.button else { return }
            if let img = NSImage(systemSymbolName: "arrow.trianglehead.2.clockwise", accessibilityDescription: "Processing") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            }
        }
    }

    func restoreIcon() {
        DispatchQueue.main.async {
            guard let button = (NSApp.delegate as? AppDelegate)?.statusItem?.button else { return }
            button.title = ""
            if let img = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Polisher") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            }
        }
    }
}
