import Foundation

class AIManager: ObservableObject {
    private var claudeProvider: ClaudeProvider
    private var openAIProvider: OpenAIProvider
    private var geminiProvider: GeminiProvider
    @Published var isProcessing = false

    init() {
        claudeProvider = ClaudeProvider(apiKey: "")
        openAIProvider = OpenAIProvider(apiKey: "")
        geminiProvider = GeminiProvider(apiKey: "")
    }

    func configure(with settings: SettingsManager) {
        claudeProvider.configure(apiKey: settings.claudeAPIKey, model: settings.selectedModel)
        openAIProvider.configure(apiKey: settings.openAIAPIKey, model: settings.selectedModel)
        geminiProvider.configure(apiKey: settings.geminiAPIKey, model: settings.selectedModel)
    }

    var currentProvider: AIProvider {
        let settings = SettingsManager()
        switch settings.selectedProvider {
        case .claude: return claudeProvider
        case .openai: return openAIProvider
        case .gemini: return geminiProvider
        }
    }

    func improveText(_ text: String, provider: AIProviderType? = nil) async throws -> String {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }

        let inputText = text
        let systemPrompt = SystemPromptManager.shared.currentPrompt
        let promptPreview = String(systemPrompt.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        LogManager.shared.log(.info, category: "Prompt", "Using: \"\(promptPreview)...\" (\(systemPrompt.count) chars)")
        guard systemPrompt.count >= 30 else {
            throw AIError.invalidPrompt
        }
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
        case .gemini:
            geminiProvider.configure(apiKey: settings.geminiAPIKey, model: settings.selectedModel)
            aiProvider = geminiProvider
        }

        let result = try await aiProvider.improveText(inputText, systemPrompt: systemPrompt)
        return result
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "--", with: "-")
    }
}
