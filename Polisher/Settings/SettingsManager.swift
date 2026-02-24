import Foundation
import Combine
import Carbon

class SettingsManager: ObservableObject {
    private let keychain = KeychainManager()

    @Published var selectedProvider: AIProviderType {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider") }
    }

    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var hotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(hotKeyEnabled, forKey: "hotKeyEnabled") }
    }

    @Published var hotKeyCode: UInt32 {
        didSet { UserDefaults.standard.set(hotKeyCode, forKey: "hotKeyCode") }
    }

    @Published var hotKeyModifiers: UInt32 {
        didSet { UserDefaults.standard.set(hotKeyModifiers, forKey: "hotKeyModifiers") }
    }

    @Published var replaceHotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(replaceHotKeyEnabled, forKey: "replaceHotKeyEnabled") }
    }

    @Published var replaceHotKeyCode: UInt32 {
        didSet { UserDefaults.standard.set(replaceHotKeyCode, forKey: "replaceHotKeyCode") }
    }

    @Published var replaceHotKeyModifiers: UInt32 {
        didSet { UserDefaults.standard.set(replaceHotKeyModifiers, forKey: "replaceHotKeyModifiers") }
    }

    var claudeAPIKey: String {
        get { keychain.load(key: "claudeAPIKey") ?? "" }
        set {
            _ = keychain.save(key: "claudeAPIKey", value: newValue)
            objectWillChange.send()
        }
    }

    var openAIAPIKey: String {
        get { keychain.load(key: "openAIAPIKey") ?? "" }
        set {
            _ = keychain.save(key: "openAIAPIKey", value: newValue)
            objectWillChange.send()
        }
    }

    var geminiAPIKey: String {
        get { keychain.load(key: "geminiAPIKey") ?? "" }
        set {
            _ = keychain.save(key: "geminiAPIKey", value: newValue)
            objectWillChange.send()
        }
    }

    init() {
        let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider") ?? AIProviderType.openai.rawValue
        self.selectedProvider = AIProviderType(rawValue: providerRaw) ?? .openai

        let savedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-5.2"
        let provider = AIProviderType(rawValue: providerRaw) ?? .openai
        let validModels: [String]
        switch provider {
        case .claude: validModels = ["claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5-20251001", "claude-sonnet-4-5", "claude-opus-4-5", "claude-opus-4-1", "claude-sonnet-4-0", "claude-opus-4-0"]
        case .openai: validModels = ["gpt-4o-mini", "gpt-4o", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1", "gpt-5", "gpt-5.1", "gpt-5.2", "gpt-5.2-pro", "o4-mini", "o3-mini", "o3", "o1", "gpt-4-turbo"]
        case .gemini: validModels = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro", "gemini-3-flash-preview", "gemini-3.1-pro-preview", "gemini-2.0-flash"]
        }
        self.selectedModel = validModels.contains(savedModel) ? savedModel : validModels[0]
        let launchDefault = UserDefaults.standard.object(forKey: "launchAtLogin")
        self.launchAtLogin = launchDefault != nil ? UserDefaults.standard.bool(forKey: "launchAtLogin") : true

        let hotKeyDefault = UserDefaults.standard.object(forKey: "hotKeyEnabled")
        self.hotKeyEnabled = hotKeyDefault != nil ? UserDefaults.standard.bool(forKey: "hotKeyEnabled") : true

        let savedKeyCode = UserDefaults.standard.object(forKey: "hotKeyCode")
        self.hotKeyCode = savedKeyCode != nil ? UInt32(UserDefaults.standard.integer(forKey: "hotKeyCode")) : 11 // 'b'

        let savedModifiers = UserDefaults.standard.object(forKey: "hotKeyModifiers")
        self.hotKeyModifiers = savedModifiers != nil ? UInt32(UserDefaults.standard.integer(forKey: "hotKeyModifiers")) : UInt32(cmdKey)

        let replaceEnabledDefault = UserDefaults.standard.object(forKey: "replaceHotKeyEnabled")
        self.replaceHotKeyEnabled = replaceEnabledDefault != nil ? UserDefaults.standard.bool(forKey: "replaceHotKeyEnabled") : true

        let savedReplaceKeyCode = UserDefaults.standard.object(forKey: "replaceHotKeyCode")
        self.replaceHotKeyCode = savedReplaceKeyCode != nil ? UInt32(UserDefaults.standard.integer(forKey: "replaceHotKeyCode")) : 50 // '`'

        let savedReplaceModifiers = UserDefaults.standard.object(forKey: "replaceHotKeyModifiers")
        self.replaceHotKeyModifiers = savedReplaceModifiers != nil ? UInt32(UserDefaults.standard.integer(forKey: "replaceHotKeyModifiers")) : UInt32(cmdKey)
    }

    func modelsForProvider(_ provider: AIProviderType) -> [String] {
        switch provider {
        case .claude:
            return ["claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5-20251001", "claude-sonnet-4-5", "claude-opus-4-5", "claude-opus-4-1", "claude-sonnet-4-0", "claude-opus-4-0"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1", "gpt-5", "gpt-5.1", "gpt-5.2", "gpt-5.2-pro", "o4-mini", "o3-mini", "o3", "o1", "gpt-4-turbo"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro", "gemini-3-flash-preview", "gemini-3.1-pro-preview", "gemini-2.0-flash"]
        }
    }

    func defaultModel(for provider: AIProviderType) -> String {
        switch provider {
        case .claude: return "claude-sonnet-4-6"
        case .openai: return "gpt-5.2"
        case .gemini: return "gemini-2.5-flash"
        }
    }

    var shortcutDisplayString: String {
        return Self.shortcutString(keyCode: hotKeyCode, modifiers: hotKeyModifiers)
    }

    var replaceShortcutDisplayString: String {
        return Self.shortcutString(keyCode: replaceHotKeyCode, modifiers: replaceHotKeyModifiers)
    }

    static func shortcutString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts = ""
        if modifiers & UInt32(controlKey) != 0 { parts += "\u{2303}" }
        if modifiers & UInt32(optionKey) != 0 { parts += "\u{2325}" }
        if modifiers & UInt32(shiftKey) != 0 { parts += "\u{21E7}" }
        if modifiers & UInt32(cmdKey) != 0 { parts += "\u{2318}" }
        parts += Self.keyCodeToString(keyCode)
        return parts
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "\u{21A9}", 48: "\u{21E5}", 49: "\u{2423}", 51: "\u{232B}",
            53: "\u{238B}", 76: "\u{2324}",
            123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
        ]
        return keyMap[keyCode] ?? "?"
    }
}
