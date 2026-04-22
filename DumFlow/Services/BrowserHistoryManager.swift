import Foundation

/// Local-only browser history. Wraps LocalHistoryService with a published interface
/// that HistoryView and WebView expect. No network calls.
@MainActor
final class BrowserHistoryManager: ObservableObject {

  static let shared = BrowserHistoryManager()
  private init() {}

  private let store = LocalHistoryService.shared

  @Published var recentHistory: [BrowserHistoryEntry] = []
  var isLoading = false
  var isLoadingMore = false
  var hasMoreData = false

  func fetchHistory() {
    recentHistory = store.allEntries()
  }

  func clearHistory() {
    store.clearAll()
    recentHistory = []
  }

  func loadMoreIfNeeded() {}

  func addToHistory(urlString: String, title: String?, referrerURL: String? = nil) {
    store.record(url: urlString, title: title)
    recentHistory = store.allEntries()
  }

  func trackPageExit() {}

  func updateScrollDepth(_ depth: Double) {}
}
