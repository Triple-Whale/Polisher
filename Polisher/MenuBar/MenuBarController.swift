import Cocoa
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let settingsManager: SettingsManager
    private let aiManager: AIManager

    init(settingsManager: SettingsManager, aiManager: AIManager) {
        self.settingsManager = settingsManager
        self.aiManager = aiManager
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Polisher")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let providerItem = NSMenuItem(title: "Provider: \(settingsManager.selectedProvider.rawValue)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        let modelItem = NSMenuItem(title: "Model: \(settingsManager.selectedModel)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        menu.addItem(NSMenuItem.separator())

        let outputModeTitle = settingsManager.autoReplace ? "Output: Auto-replace" : "Output: Clipboard + Notification"
        let outputItem = NSMenuItem(title: outputModeTitle, action: #selector(toggleOutputMode), keyEquivalent: "")
        outputItem.target = self
        menu.addItem(outputItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Polisher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.delegate = self

        return menu
    }

    @objc private func toggleOutputMode() {
        settingsManager.autoReplace.toggle()
        statusItem.menu = buildMenu()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        statusItem.menu = buildMenu()
    }
}
