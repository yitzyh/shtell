import Foundation

struct BrowserHistoryEntry: Codable, Identifiable, Equatable {
  let id: String       // UUID string
  let url: String
  let title: String?
  let domain: String
  let dateVisited: String // ISO 8601

  static func make(url: String, title: String?) -> BrowserHistoryEntry {
    BrowserHistoryEntry(
      id: UUID().uuidString,
      url: url,
      title: title,
      domain: URL(string: url)?.host ?? "unknown",
      dateVisited: ISO8601DateFormatter().string(from: Date())
    )
  }
}
