import Foundation

class OpenAIProvider: AIProvider {
    let providerType: AIProviderType = .openai
    let availableModels = [
        "gpt-4o-mini",
        "gpt-4o",
        "gpt-4.1-nano",
        "gpt-4.1-mini",
        "gpt-4.1",
        "o4-mini",
        "o3-mini",
        "o1",
        "gpt-4-turbo",
    ]

    private var apiKey: String
    private var model: String

    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }

    func configure(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    func improveText(_ text: String, systemPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "max_tokens": 4096,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]

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
