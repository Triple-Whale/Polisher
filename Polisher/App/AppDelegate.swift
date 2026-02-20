import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let settingsManager = SettingsManager()
    let aiManager = AIManager()
    let notificationManager = NotificationManager()
    var servicesProvider: ServicesProvider!
    var globalHotKey: GlobalHotKey!
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Polisher menu bar app")
        NSApp.disableRelaunchOnLogin()

        setupStatusItem()

        servicesProvider = ServicesProvider(
            aiManager: aiManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager
        )
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()

        globalHotKey = GlobalHotKey(
            aiManager: aiManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager
        )
        globalHotKey.register()

        let detector = APIKeyDetector()
        if settingsManager.claudeAPIKey.isEmpty, let key = detector.detectClaudeKey() {
            settingsManager.claudeAPIKey = key
        }
        if settingsManager.openAIAPIKey.isEmpty, let key = detector.detectOpenAIKey() {
            settingsManager.openAIAPIKey = key
        }

        aiManager.configure(with: settingsManager)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        SystemPromptManager.shared.refreshIfNeeded()
    }

    private func setupStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }

        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Polisher") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
                button.title = ""
            } else {
                button.title = "P"
                button.image = nil
            }
        }

        let menu = NSMenu()

        let providerItem = NSMenuItem(title: "Provider: \(settingsManager.selectedProvider.rawValue)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        let modelItem = NSMenuItem(title: "Model: \(settingsManager.selectedModel)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        menu.addItem(NSMenuItem.separator())

        let outputTitle = settingsManager.autoReplace ? "Mode: Auto-replace" : "Mode: Clipboard + Notification"
        let outputItem = NSMenuItem(title: outputTitle, action: #selector(toggleOutputMode), keyEquivalent: "")
        outputItem.target = self
        menu.addItem(outputItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Polisher", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    @objc private func toggleOutputMode() {
        settingsManager.autoReplace.toggle()
        setupStatusItem()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(settingsManager)
            .environmentObject(aiManager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Polisher Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}

extension AppDelegate {
    private func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let providerItem = NSMenuItem(title: "Provider: \(settingsManager.selectedProvider.rawValue)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        let modelItem = NSMenuItem(title: "Model: \(settingsManager.selectedModel)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        menu.addItem(NSMenuItem.separator())

        let outputTitle = settingsManager.autoReplace ? "Mode: Auto-replace" : "Mode: Clipboard + Notification"
        let outputItem = NSMenuItem(title: outputTitle, action: #selector(toggleOutputMode), keyEquivalent: "")
        outputItem.target = self
        menu.addItem(outputItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Polisher", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
}
