import Foundation

class OpenAIProvider: AIProvider {
    let providerType: AIProviderType = .openai
    let availableModels: [String] = []

    private var apiKey: String
    private var model: String

    init(apiKey: String, model: String = "gpt-5.4") {
        self.apiKey = apiKey
        self.model = model
    }

    func configure(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    private var isReasoningModel: Bool {
        if model.hasPrefix("o1") || model.hasPrefix("o3") || model.hasPrefix("o4") {
            return true
        }
        if model.hasSuffix("-pro") {
            return true
        }
        let noTempModels = ["gpt-5", "gpt-5.1", "gpt-5-mini", "gpt-5-nano"]
        if noTempModels.contains(model) {
            return true
        }
        return false
    }

    private var usesLegacyMaxTokens: Bool {
        return model.hasPrefix("gpt-4o") || model.hasPrefix("gpt-4-")
    }

    func improveText(_ text: String, systemPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let tokensKey = usesLegacyMaxTokens ? "max_tokens" : "max_completion_tokens"

        var body: [String: Any] = [
            "model": model,
            tokensKey: 4096,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]

        if !isReasoningModel {
            body["temperature"] = 0.3
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            LogManager.shared.log(.error, category: "OpenAI", "HTTP \(httpResponse.statusCode): \(errorBody)")
            throw AIError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
