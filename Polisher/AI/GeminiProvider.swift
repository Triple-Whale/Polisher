import Foundation

class GeminiProvider: AIProvider {
    let providerType: AIProviderType = .gemini
    let availableModels: [String] = []

    private var apiKey: String
    private var model: String

    init(apiKey: String, model: String = "") {
        self.apiKey = apiKey
        self.model = model
    }

    func configure(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    func improveText(_ text: String, systemPrompt: String) async throws -> AIResult {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["parts": [["text": text]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 4096,
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            LogManager.shared.log(.error, category: "Gemini", "HTTP \(httpResponse.statusCode): \(errorBody)")
            throw AIError.httpError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIError.invalidResponse
        }

        var inputTokens = 0
        var outputTokens = 0
        if let usage = json["usageMetadata"] as? [String: Any] {
            inputTokens = usage["promptTokenCount"] as? Int ?? 0
            outputTokens = usage["candidatesTokenCount"] as? Int ?? 0
        }

        return AIResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }
}
