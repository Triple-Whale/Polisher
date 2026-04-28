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
    @Published var pricing: [String: ModelPricing] = [:]
    @Published var modelOptions: [String: ModelOptions] = [:]

    private static let emptyConfig = ModelsConfig(models: [:], defaults: [:], systemPrompt: nil, modelOptions: nil, pricing: nil)
    private static let bundledConfig: ModelsConfig = {
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(ModelsConfig.self, from: data) else {
            return emptyConfig
        }
        return config
    }()

    private init() {
        loadCached()
        if models.isEmpty {
            apply(Self.bundledConfig)
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
        return models[provider.rawValue] ?? Self.bundledConfig.models[provider.rawValue] ?? []
    }

    func defaultModel(for provider: AIProviderType) -> String {
        if let defaultModel = defaults[provider.rawValue] ?? Self.bundledConfig.defaults[provider.rawValue] {
            return defaultModel
        }
        return modelsForProvider(provider).first ?? ""
    }

    func defaultSystemPrompt() -> String {
        return remoteSystemPrompt ?? Self.bundledConfig.systemPrompt ?? ""
    }

    func optionsForModel(_ model: String) -> ModelOptions {
        return modelOptions[model] ?? Self.bundledConfig.modelOptions?[model] ?? ModelOptions()
    }

    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let config = try? JSONDecoder().decode(ModelsConfig.self, from: data) else {
            return
        }
        apply(config)
    }

    func costForModel(_ model: String, inputTokens: Int, outputTokens: Int) -> Double {
        guard let p = pricing[model] else { return 0 }
        return (Double(inputTokens) / 1_000_000 * p.input) + (Double(outputTokens) / 1_000_000 * p.output)
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
                self.apply(config)
                LogManager.shared.log(.success, category: "Models", "Loaded \(config.models.values.flatMap { $0 }.count) models from GCS")
            }
        } catch {
            LogManager.shared.log(.debug, category: "Models", "GCS fetch error: \(error.localizedDescription)")
        }
    }

    private func apply(_ config: ModelsConfig) {
        models = config.models
        defaults = config.defaults
        remoteSystemPrompt = config.systemPrompt
        pricing = config.pricing ?? [:]
        modelOptions = config.modelOptions ?? [:]
    }
}

struct ModelPricing: Codable {
    let input: Double
    let output: Double
}

struct ModelOptions: Codable {
    let api: String?
    let supportsTemperature: Bool?
    let tokenParameter: String?

    init(api: String? = nil, supportsTemperature: Bool? = nil, tokenParameter: String? = nil) {
        self.api = api
        self.supportsTemperature = supportsTemperature
        self.tokenParameter = tokenParameter
    }
}

struct ModelsConfig: Codable {
    let models: [String: [String]]
    let defaults: [String: String]
    let systemPrompt: String?
    let modelOptions: [String: ModelOptions]?
    let pricing: [String: ModelPricing]?
}
