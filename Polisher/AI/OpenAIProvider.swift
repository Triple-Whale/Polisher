import Foundation

class OpenAIProvider: AIProvider {
    let providerType: AIProviderType = .openai
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

    private var modelOptions: ModelOptions {
        return ModelConfigManager.shared.optionsForModel(model)
    }

    private var usesResponsesAPI: Bool {
        return modelOptions.api == "responses"
    }

    func improveText(_ text: String, systemPrompt: String) async throws -> AIResult {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }
        if usesResponsesAPI {
            return try await improveTextWithResponsesAPI(text, systemPrompt: systemPrompt)
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let tokensKey = modelOptions.tokenParameter ?? "max_completion_tokens"

        var body: [String: Any] = [
            "model": model,
            tokensKey: 4096,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]

        if modelOptions.supportsTemperature ?? true {
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

        var inputTokens = 0
        var outputTokens = 0
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["prompt_tokens"] as? Int ?? 0
            outputTokens = usage["completion_tokens"] as? Int ?? 0
        }

        return AIResult(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    private func improveTextWithResponsesAPI(_ text: String, systemPrompt: String) async throws -> AIResult {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": model,
            "instructions": systemPrompt,
            "input": text,
            "max_output_tokens": 4096
        ]

        if modelOptions.supportsTemperature ?? true {
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
              let content = extractResponsesText(from: json) else {
            throw AIError.invalidResponse
        }

        var inputTokens = 0
        var outputTokens = 0
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["input_tokens"] as? Int ?? 0
            outputTokens = usage["output_tokens"] as? Int ?? 0
        }

        return AIResult(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    private func extractResponsesText(from json: [String: Any]) -> String? {
        if let outputText = json["output_text"] as? String {
            return outputText
        }

        guard let output = json["output"] as? [[String: Any]] else {
            return nil
        }

        for item in output {
            guard let content = item["content"] as? [[String: Any]] else {
                continue
            }
            for block in content {
                if let text = block["text"] as? String {
                    return text
                }
                if let outputText = block["output_text"] as? String {
                    return outputText
                }
            }
        }

        return nil
    }
}
