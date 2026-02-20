import Foundation

class APIKeyDetector {
    func detectClaudeKey() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        let credentialsPath = homeDir.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: credentialsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let key = json["apiKey"] as? String, !key.isEmpty {
            return key
        }

        let configPath = homeDir.appendingPathComponent(".config/anthropic/api_key")
        if let key = try? String(contentsOf: configPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }

        return nil
    }

    func detectOpenAIKey() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        let configPath = homeDir.appendingPathComponent(".config/openai/api_key")
        if let key = try? String(contentsOf: configPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }

        return nil
    }
}
