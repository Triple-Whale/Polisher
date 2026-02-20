import Foundation

class AIManager: ObservableObject {
    private var claudeProvider: ClaudeProvider
    private var openAIProvider: OpenAIProvider
    @Published var isProcessing = false

    init() {
        claudeProvider = ClaudeProvider(apiKey: "")
        openAIProvider = OpenAIProvider(apiKey: "")
    }

    func configure(with settings: SettingsManager) {
        claudeProvider.configure(apiKey: settings.claudeAPIKey, model: settings.selectedModel)
        openAIProvider.configure(apiKey: settings.openAIAPIKey, model: settings.selectedModel)
    }

    var currentProvider: AIProvider {
        let settings = SettingsManager()
        switch settings.selectedProvider {
        case .claude: return claudeProvider
        case .openai: return openAIProvider
        }
    }

    func improveText(_ text: String, provider: AIProviderType? = nil) async throws -> String {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }

        let systemPrompt = SystemPromptManager.shared.currentPrompt
        let settings = SettingsManager()
        let selectedProvider = provider ?? settings.selectedProvider

        let aiProvider: AIProvider
        switch selectedProvider {
        case .claude:
            claudeProvider.configure(apiKey: settings.claudeAPIKey, model: settings.selectedModel)
            aiProvider = claudeProvider
        case .openai:
            openAIProvider.configure(apiKey: settings.openAIAPIKey, model: settings.selectedModel)
            aiProvider = openAIProvider
        }

        return try await aiProvider.improveText(text, systemPrompt: systemPrompt)
    }
}
