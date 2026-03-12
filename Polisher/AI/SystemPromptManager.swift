import Foundation
import Combine

class SystemPromptManager: ObservableObject {
    static let shared = SystemPromptManager()

    static let defaultPrompt = """
    Fix grammar, spelling, and punctuation errors. Make the text sound professional and polished. \
    Preserve the original meaning, tone, and intent. Preserve the original line breaks and paragraph structure exactly. \
    Never use double dashes (--) or em dashes. Use a single dash (-) instead. \
    Return ONLY the improved text with no explanations, preamble, or quotes around it.
    """

    private let userPromptKey = "userSystemPrompt"
    private var cancellable: AnyCancellable?

    @Published var customPrompt: String

    var currentPrompt: String {
        if !customPrompt.isEmpty {
            return customPrompt
        }
        if let remote = ModelConfigManager.shared.remoteSystemPrompt, !remote.isEmpty {
            return remote
        }
        return Self.defaultPrompt
    }

    private init() {
        self.customPrompt = UserDefaults.standard.string(forKey: userPromptKey) ?? Self.defaultPrompt
        self.cancellable = $customPrompt
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                UserDefaults.standard.set(newValue, forKey: self.userPromptKey)
            }
    }

    func resetToDefault() {
        if let remote = ModelConfigManager.shared.remoteSystemPrompt, !remote.isEmpty {
            customPrompt = remote
        } else {
            customPrompt = Self.defaultPrompt
        }
    }

    func refreshIfNeeded() {
        ModelConfigManager.shared.refreshIfNeeded()
    }
}
