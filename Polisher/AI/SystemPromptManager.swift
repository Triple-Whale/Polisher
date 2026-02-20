import Foundation

class SystemPromptManager: ObservableObject {
    static let shared = SystemPromptManager()

    static let defaultPrompt = """
    Fix grammar, spelling, and punctuation errors. Make the text sound professional and polished. \
    Preserve the original meaning, tone, and intent. Never use double dashes (--) or em dashes. \
    Use a single dash (-) instead. Return ONLY the improved text with no \
    explanations, preamble, or quotes around it.
    """

    private let userPromptKey = "userSystemPrompt"
    private let gcsURL = "https://storage.googleapis.com/polisher-config/system-prompt.txt"
    private let cacheKey = "cachedSystemPrompt"
    private let lastFetchKey = "lastPromptFetch"
    private let refreshInterval: TimeInterval = 3600

    @Published var customPrompt: String {
        didSet {
            UserDefaults.standard.set(customPrompt, forKey: userPromptKey)
        }
    }

    var currentPrompt: String {
        if !customPrompt.isEmpty {
            return customPrompt
        }
        if let cached = UserDefaults.standard.string(forKey: cacheKey), !cached.isEmpty {
            return cached
        }
        return Self.defaultPrompt
    }

    private init() {
        self.customPrompt = UserDefaults.standard.string(forKey: userPromptKey) ?? Self.defaultPrompt
    }

    func resetToDefault() {
        customPrompt = Self.defaultPrompt
    }

    func refreshIfNeeded() {
        let lastFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let now = Date().timeIntervalSince1970

        if now - lastFetch > refreshInterval {
            Task { await fetchFromGCS() }
        }
    }

    private func fetchFromGCS() async {
        guard let url = URL(string: gcsURL) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let prompt = String(data: data, encoding: .utf8),
                  !prompt.isEmpty else {
                return
            }

            UserDefaults.standard.set(prompt.trimmingCharacters(in: .whitespacesAndNewlines), forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
        } catch {
            // GCS fetch failed - use cached/default prompt
        }
    }
}
