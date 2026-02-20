import Foundation

class SystemPromptManager {
    static let shared = SystemPromptManager()

    private let defaultPrompt = """
    Fix grammar, spelling, and punctuation errors. Make the text sound professional and polished. \
    Preserve the original meaning, tone, and intent. Return ONLY the improved text with no \
    explanations, preamble, or quotes around it.
    """

    private let gcsURL = "https://storage.googleapis.com/polisher-config/system-prompt.txt"
    private let cacheKey = "cachedSystemPrompt"
    private let lastFetchKey = "lastPromptFetch"
    private let refreshInterval: TimeInterval = 3600

    var currentPrompt: String {
        if let cached = UserDefaults.standard.string(forKey: cacheKey), !cached.isEmpty {
            return cached
        }
        return defaultPrompt
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
