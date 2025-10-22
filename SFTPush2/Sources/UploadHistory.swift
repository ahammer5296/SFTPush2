import Foundation

struct UploadHistoryEntry: Codable {
    let name: String
    let urlString: String
    let date: Date

    var url: URL? { URL(string: urlString) }
}

final class HistoryStore {
    static let shared = HistoryStore()
    private let key = "uploadHistoryEntries"
    private let defaults: UserDefaults
    private let prefs: Preferences
    private var entries: [UploadHistoryEntry] = []

    private init(defaults: UserDefaults = .standard, prefs: Preferences = .shared) {
        self.defaults = defaults
        self.prefs = prefs
        load()
    }

    func all() -> [UploadHistoryEntry] { entries }

    func add(name: String, url: URL) {
        let entry = UploadHistoryEntry(name: name, urlString: url.absoluteString, date: Date())
        entries.insert(entry, at: 0)
        trim()
        save()
    }

    func trim() {
        let cap = prefs.historyMaxEntries
        if entries.count > cap { entries = Array(entries.prefix(cap)) }
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([UploadHistoryEntry].self, from: data) {
            entries = decoded
            trim()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }
}

