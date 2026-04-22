import Foundation

final class LocalHistoryService {
  static let shared = LocalHistoryService()
  private init() {}

  private let storageKey = "browserHistory"
  private let maxEntries = 500
  private let defaults = UserDefaults.standard

  // MARK: - Read

  func allEntries() -> [BrowserHistoryEntry] {
    guard let data = defaults.data(forKey: storageKey),
          let entries = try? JSONDecoder().decode([BrowserHistoryEntry].self, from: data)
    else { return [] }
    return entries
  }

  // MARK: - Write

  func record(url: String, title: String?) {
    var entries = allEntries()

    // Remove existing entry for this URL (move-to-front)
    entries.removeAll { $0.url == url }

    // Prepend new entry
    entries.insert(.make(url: url, title: title), at: 0)

    // Trim to max
    if entries.count > maxEntries {
      entries = Array(entries.prefix(maxEntries))
    }

    save(entries)
  }

  func removeEntry(id: String) {
    var entries = allEntries()
    entries.removeAll { $0.id == id }
    save(entries)
  }

  func clearAll() {
    defaults.removeObject(forKey: storageKey)
  }

  // MARK: - Private

  private func save(_ entries: [BrowserHistoryEntry]) {
    guard let data = try? JSONEncoder().encode(entries) else { return }
    defaults.set(data, forKey: storageKey)
  }
}
