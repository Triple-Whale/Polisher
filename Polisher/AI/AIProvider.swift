import Foundation

enum AIProviderType: String, CaseIterable, Codable {
    case claude = "Claude"
    case openai = "OpenAI"
}

protocol AIProvider {
    var providerType: AIProviderType { get }
    var availableModels: [String] { get }
    func improveText(_ text: String, systemPrompt: String) async throws -> String
}

enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured"
        case .invalidResponse: return "Invalid response from AI"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}
