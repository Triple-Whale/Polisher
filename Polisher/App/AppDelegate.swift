import Cocoa
import SwiftUI
import UserNotifications
import Combine

class EditableWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }

        switch event.charactersIgnoringModifiers {
        case "v":
            firstResponder?.tryToPerform(#selector(NSText.paste(_:)), with: nil)
            return true
        case "c":
            firstResponder?.tryToPerform(#selector(NSText.copy(_:)), with: nil)
            return true
        case "x":
            firstResponder?.tryToPerform(#selector(NSText.cut(_:)), with: nil)
            return true
        case "a":
            firstResponder?.tryToPerform(#selector(NSText.selectAll(_:)), with: nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let settingsManager = SettingsManager()
    let aiManager = AIManager()
    let notificationManager = NotificationManager()
    let historyManager = HistoryManager()
    var servicesProvider: ServicesProvider!
    var globalHotKey: GlobalHotKey!
    var settingsWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Polisher menu bar app")
        NSApp.disableRelaunchOnLogin()

        setupMainMenu()
        setupStatusItem()

        servicesProvider = ServicesProvider(
            aiManager: aiManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager,
            historyManager: historyManager
        )
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()

        globalHotKey = GlobalHotKey(
            aiManager: aiManager,
            settingsManager: settingsManager,
            notificationManager: notificationManager,
            historyManager: historyManager
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

        setupProcessingIndicator()
        setupShortcutObserver()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        LogManager.shared.log(.info, category: "App", "Polisher v\(version) started")
        LogManager.shared.log(.info, category: "App", "Provider: \(settingsManager.selectedProvider.rawValue), Model: \(settingsManager.selectedModel)")
    }

    private func setupProcessingIndicator() {
        aiManager.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                guard let self, let button = self.statusItem?.button else { return }
                if isProcessing {
                    button.title = " Polishing..."
                    if let img = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Processing") {
                        img.size = NSSize(width: 18, height: 18)
                        img.isTemplate = true
                        button.image = img
                    }
                } else {
                    button.title = ""
                    if let img = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Polisher") {
                        img.size = NSSize(width: 18, height: 18)
                        img.isTemplate = true
                        button.image = img
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupShortcutObserver() {
        Publishers.CombineLatest(
            settingsManager.$hotKeyCode,
            settingsManager.$hotKeyModifiers
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.globalHotKey.reregister()
        }
        .store(in: &cancellables)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
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

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let versionItem = NSMenuItem(title: "Polisher v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem.separator())

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
        NSApp.setActivationPolicy(.regular)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(settingsManager)
            .environmentObject(aiManager)
            .environmentObject(historyManager)

        let window = EditableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Polisher Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
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

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let versionItem = NSMenuItem(title: "Polisher v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem.separator())

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
