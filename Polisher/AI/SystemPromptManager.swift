import Foundation
import Combine

class SystemPromptManager: ObservableObject {
    static let shared = SystemPromptManager()

    private let userPromptKey = "userSystemPrompt"
    private var cancellable: AnyCancellable?

    @Published var customPrompt: String

    var defaultPrompt: String {
        return ModelConfigManager.shared.defaultSystemPrompt()
    }

    var currentPrompt: String {
        if !customPrompt.isEmpty {
            return customPrompt
        }
        if let remote = ModelConfigManager.shared.remoteSystemPrompt, !remote.isEmpty {
            return remote
        }
        return defaultPrompt
    }

    private init() {
        self.customPrompt = UserDefaults.standard.string(forKey: userPromptKey) ?? ModelConfigManager.shared.defaultSystemPrompt()
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
            customPrompt = defaultPrompt
        }
    }

    func refreshIfNeeded() {
        ModelConfigManager.shared.refreshIfNeeded()
    }
}
