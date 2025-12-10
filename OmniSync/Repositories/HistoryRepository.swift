import Foundation

final class HistoryRepository {
    private let fileURL: URL
    private let maxEntries: Int

    init(fileURL: URL, maxEntries: Int = 50) {
        self.fileURL = fileURL
        self.maxEntries = maxEntries
    }

    func loadHistory() -> [SyncHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SyncHistoryEntry].self, from: data)) ?? []
    }

    func saveHistory(_ history: [SyncHistoryEntry]) {
        let limitedHistory = Array(history.prefix(maxEntries))
        guard let data = try? JSONEncoder().encode(limitedHistory) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func addEntry(_ entry: SyncHistoryEntry) {
        var history = loadHistory()
        history.insert(entry, at: 0)
        if history.count > maxEntries {
            history = Array(history.prefix(maxEntries))
        }
        saveHistory(history)
    }
}
