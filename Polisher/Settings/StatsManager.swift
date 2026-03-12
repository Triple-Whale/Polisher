import Foundation

struct ModelStats: Codable {
    var polishes: Int = 0
    var charsInput: Int = 0
    var charsOutput: Int = 0
    var totalTime: Double = 0
    var totalCost: Double = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0

    var averageTime: Double {
        guard polishes > 0 else { return 0 }
        return totalTime / Double(polishes)
    }
}

class StatsManager: ObservableObject {
    static let shared = StatsManager()

    private let modelStatsKey = "stats_modelStats"
    private let firstUseDateKey = "stats_firstUseDate"

    @Published var modelStats: [String: ModelStats]
    @Published var firstUseDate: Date?

    private init() {
        if let data = UserDefaults.standard.data(forKey: modelStatsKey),
           let decoded = try? JSONDecoder().decode([String: ModelStats].self, from: data) {
            modelStats = decoded
        } else {
            modelStats = [:]
        }

        let timestamp = UserDefaults.standard.double(forKey: firstUseDateKey)
        firstUseDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    func recordPolish(inputChars: Int, outputChars: Int, elapsedSeconds: Double, provider: String, model: String, inputTokens: Int, outputTokens: Int) {
        if firstUseDate == nil {
            firstUseDate = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: firstUseDateKey)
        }

        let cost = ModelConfigManager.shared.costForModel(model, inputTokens: inputTokens, outputTokens: outputTokens)

        var stats = modelStats[model] ?? ModelStats()
        stats.polishes += 1
        stats.charsInput += inputChars
        stats.charsOutput += outputChars
        stats.totalTime += elapsedSeconds
        stats.totalCost += cost
        stats.inputTokens += inputTokens
        stats.outputTokens += outputTokens
        modelStats[model] = stats

        save()
    }

    func resetAll() {
        modelStats = [:]
        firstUseDate = nil
        UserDefaults.standard.removeObject(forKey: firstUseDateKey)
        save()
    }

    var totalPolishes: Int {
        modelStats.values.reduce(0) { $0 + $1.polishes }
    }

    var totalCharsInput: Int {
        modelStats.values.reduce(0) { $0 + $1.charsInput }
    }

    var totalCharsOutput: Int {
        modelStats.values.reduce(0) { $0 + $1.charsOutput }
    }

    var totalTimeSeconds: Double {
        modelStats.values.reduce(0) { $0 + $1.totalTime }
    }

    var totalCost: Double {
        modelStats.values.reduce(0) { $0 + $1.totalCost }
    }

    var averageTimePerPolish: Double {
        guard totalPolishes > 0 else { return 0 }
        return totalTimeSeconds / Double(totalPolishes)
    }

    var sortedModels: [(model: String, stats: ModelStats)] {
        modelStats.sorted { $0.value.polishes > $1.value.polishes }
            .map { (model: $0.key, stats: $0.value) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(modelStats) {
            UserDefaults.standard.set(data, forKey: modelStatsKey)
        }
    }
}
