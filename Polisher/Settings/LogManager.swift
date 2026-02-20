import Foundation

enum LogLevel: String, CaseIterable {
    case info = "Info"
    case success = "Success"
    case error = "Error"
    case debug = "Debug"

    var symbol: String {
        switch self {
        case .info: return "i"
        case .success: return "\u{2713}"
        case .error: return "\u{2717}"
        case .debug: return "\u{2699}"
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String

    var formattedTime: String {
        Self.formatter.string(from: timestamp)
    }

    var exportLine: String {
        "[\(formattedTime)] [\(level.rawValue)] [\(category)] \(message)"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

class LogManager: ObservableObject {
    static let shared = LogManager()
    private static let maxEntries = 500

    @Published var entries: [LogEntry] = []

    func log(_ level: LogLevel, category: String, _ message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > Self.maxEntries {
                self.entries.removeFirst(self.entries.count - Self.maxEntries)
            }
        }
        NSLog("[Polisher] [%@] [%@] %@", level.rawValue, category, message)
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }

    func exportAll() -> String {
        entries.map { $0.exportLine }.joined(separator: "\n")
    }
}
