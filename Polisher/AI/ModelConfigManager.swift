import Foundation
import Combine

class ModelConfigManager: ObservableObject {
    static let shared = ModelConfigManager()

    private let gcsURL = "https://storage.googleapis.com/polisher-config/models.json"
    private let cacheKey = "cachedModelsConfig"
    private let lastFetchKey = "lastModelsFetch"
    private let refreshInterval: TimeInterval = 3600

    @Published var models: [String: [String]] = [:]
    @Published var defaults: [String: String] = [:]
    @Published var remoteSystemPrompt: String?

    private static let fallbackModels: [String: [String]] = [
        "Claude": ["claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5-20251001", "claude-sonnet-4-5", "claude-opus-4-5", "claude-opus-4-1", "claude-sonnet-4-0", "claude-opus-4-0"],
        "OpenAI": ["gpt-4o-mini", "gpt-4o", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1", "gpt-5", "gpt-5.1", "gpt-5.2", "gpt-5.2-pro", "o4-mini", "o3-mini", "o3", "o1", "gpt-4-turbo"],
        "Gemini": ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro", "gemini-3-flash-preview", "gemini-3.1-pro-preview", "gemini-2.0-flash"]
    ]

    private static let fallbackDefaults: [String: String] = [
        "Claude": "claude-sonnet-4-6",
        "OpenAI": "gpt-5.2",
        "Gemini": "gemini-2.5-flash"
    ]

    private init() {
        loadCached()
        if models.isEmpty {
            models = Self.fallbackModels
            defaults = Self.fallbackDefaults
        }
    }

    func refreshIfNeeded() {
        let lastFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let now = Date().timeIntervalSince1970
        if now - lastFetch > refreshInterval {
            Task { await fetchFromGCS() }
        }
    }

    func forceRefresh() {
        Task { await fetchFromGCS() }
    }

    func modelsForProvider(_ provider: AIProviderType) -> [String] {
        return models[provider.rawValue] ?? Self.fallbackModels[provider.rawValue] ?? []
    }

    func defaultModel(for provider: AIProviderType) -> String {
        return defaults[provider.rawValue] ?? Self.fallbackDefaults[provider.rawValue] ?? ""
    }

    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let config = try? JSONDecoder().decode(ModelsConfig.self, from: data) else {
            return
        }
        models = config.models
        defaults = config.defaults
        remoteSystemPrompt = config.systemPrompt
    }

    private func fetchFromGCS() async {
        guard let url = URL(string: gcsURL) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                LogManager.shared.log(.debug, category: "Models", "GCS fetch failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            let config = try JSONDecoder().decode(ModelsConfig.self, from: data)

            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)

            await MainActor.run {
                self.models = config.models
                self.defaults = config.defaults
                self.remoteSystemPrompt = config.systemPrompt
                LogManager.shared.log(.success, category: "Models", "Loaded \(config.models.values.flatMap { $0 }.count) models from GCS")
            }
        } catch {
            LogManager.shared.log(.debug, category: "Models", "GCS fetch error: \(error.localizedDescription)")
        }
    }
}

struct ModelsConfig: Codable {
    let models: [String: [String]]
    let defaults: [String: String]
    let systemPrompt: String?
}
