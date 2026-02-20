import Foundation

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let improvedText: String
    let timestamp: Date

    init(originalText: String, improvedText: String) {
        self.id = UUID()
        self.originalText = originalText
        self.improvedText = improvedText
        self.timestamp = Date()
    }
}

class HistoryManager: ObservableObject {
    private static let maxEntries = 20
    private static let storageKey = "polisherHistory"

    @Published var entries: [HistoryEntry] = []

    init() {
        loadEntries()
    }

    func addEntry(original: String, improved: String) {
        let entry = HistoryEntry(originalText: original, improvedText: improved)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        saveEntries()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    func clearAll() {
        entries.removeAll()
        saveEntries()
    }

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }
}
