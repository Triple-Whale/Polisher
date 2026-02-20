import Foundation

enum AIProviderType: String, CaseIterable, Codable {
    case claude = "Claude"
    case openai = "OpenAI"
    case gemini = "Gemini"
}

protocol AIProvider {
    var providerType: AIProviderType { get }
    var availableModels: [String] { get }
    func improveText(_ text: String, systemPrompt: String) async throws -> String
}

enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case invalidPrompt
    case httpError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured"
        case .invalidResponse: return "Invalid response from AI"
        case .invalidPrompt: return "System prompt must be at least 30 characters"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}
