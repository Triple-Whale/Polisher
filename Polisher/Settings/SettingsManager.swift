import Foundation
import Combine

class SettingsManager: ObservableObject {
    private let keychain = KeychainManager()

    @Published var selectedProvider: AIProviderType {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider") }
    }

    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }

    @Published var autoReplace: Bool {
        didSet { UserDefaults.standard.set(autoReplace, forKey: "autoReplace") }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var hotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(hotKeyEnabled, forKey: "hotKeyEnabled") }
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

    init() {
        let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider") ?? AIProviderType.claude.rawValue
        self.selectedProvider = AIProviderType(rawValue: providerRaw) ?? .claude

        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "claude-sonnet-4-5-20250514"
        self.autoReplace = UserDefaults.standard.bool(forKey: "autoReplace")
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")

        let hotKeyDefault = UserDefaults.standard.object(forKey: "hotKeyEnabled")
        self.hotKeyEnabled = hotKeyDefault != nil ? UserDefaults.standard.bool(forKey: "hotKeyEnabled") : true
    }

    func modelsForProvider(_ provider: AIProviderType) -> [String] {
        switch provider {
        case .claude:
            return ["claude-sonnet-4-5-20250514", "claude-haiku-4-5-20251001", "claude-opus-4-5-20250514"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo"]
        }
    }

    func defaultModel(for provider: AIProviderType) -> String {
        switch provider {
        case .claude: return "claude-sonnet-4-5-20250514"
        case .openai: return "gpt-4o-mini"
        }
    }
}
