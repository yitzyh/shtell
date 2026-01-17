//
//  TabStateManager.swift
//  DumFlow
//
//  Created by Tab 4 - Horizontal Navigation
//  TestFlight 2.1.0 Sprint
//

import SwiftUI
import WebKit
import Combine

/// Manages persistent state for all browser tabs
/// Preserves URL, scroll position, and navigation history
class TabStateManager: NSObject, ObservableObject {
  // MARK: - Tab State Storage
  @Published var tabs: [TabState] = []
  @Published var activeTabId: UUID?

  // WebView management
  private var webViewPool: [UUID: WKWebView] = [:]
  private var scrollObservers: [UUID: AnyCancellable] = [:]

  // Configuration
  let maxTabs = 5
  let stateArchiveKey = "ShtellTabStates"

  // Memory management
  private var memoryPressureObserver: AnyCancellable?
  private let memoryWarningThreshold: Float = 180.0 // MB

  // MARK: - Tab State Model

  struct TabState: Codable, Identifiable {
    let id: UUID
    var url: URL?
    var title: String
    var favicon: Data? // Encoded image data
    var scrollPosition: ScrollPosition
    var history: [HistoryItem]
    var currentHistoryIndex: Int
    var lastAccessed: Date
    var isLoading: Bool
    var estimatedProgress: Double

    // Navigation state
    var canGoBack: Bool
    var canGoForward: Bool

    // Content state
    var pageHTML: String?
    // Note: HTTPCookie is not Codable, store as encoded data instead
    var cookiesData: Data?

    init(id: UUID = UUID()) {
      self.id = id
      self.url = nil
      self.title = "New Tab"
      self.favicon = nil
      self.scrollPosition = ScrollPosition()
      self.history = []
      self.currentHistoryIndex = -1
      self.lastAccessed = Date()
      self.isLoading = false
      self.estimatedProgress = 0
      self.canGoBack = false
      self.canGoForward = false
      self.pageHTML = nil
      self.cookiesData = nil
    }
  }

  struct ScrollPosition: Codable {
    var x: CGFloat = 0
    var y: CGFloat = 0
  }

  struct HistoryItem: Codable {
    let url: URL
    let title: String
    let visitedAt: Date
  }

  // MARK: - Initialization

  override init() {
    super.init()
    loadPersistedState()
    setupMemoryMonitoring()
    createInitialTabIfNeeded()
  }

  private func createInitialTabIfNeeded() {
    if tabs.isEmpty {
      let initialTab = TabState()
      tabs.append(initialTab)
      activeTabId = initialTab.id
    }
  }

  // MARK: - Tab Creation & Management

  func createNewTab(url: URL? = nil) -> UUID {
    guard tabs.count < maxTabs else {
      print("Maximum tab limit reached")
      return activeTabId ?? UUID()
    }

    var newTab = TabState()
    if let url = url {
      newTab.url = url
      newTab.title = url.host ?? "Loading..."
    }

    tabs.append(newTab)
    activeTabId = newTab.id

    // Create WebView for new tab
    createWebView(for: newTab.id)

    // Persist state
    saveState()

    // Notify observers
    NotificationCenter.default.post(
      name: .tabCreated,
      object: nil,
      userInfo: ["tabId": newTab.id]
    )

    return newTab.id
  }

  func closeTab(id: UUID) {
    guard tabs.count > 1 else {
      print("Cannot close last tab")
      return
    }

    // Find tab index
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

    // Clean up WebView
    if let webView = webViewPool[id] {
      webView.stopLoading()
      webView.navigationDelegate = nil
      webViewPool.removeValue(forKey: id)
    }

    // Cancel scroll observer
    scrollObservers[id]?.cancel()
    scrollObservers.removeValue(forKey: id)

    // Remove tab
    tabs.remove(at: index)

    // Update active tab if needed
    if activeTabId == id {
      let newIndex = min(index, tabs.count - 1)
      activeTabId = tabs[newIndex].id
    }

    // Persist state
    saveState()

    // Notify observers
    NotificationCenter.default.post(
      name: .tabClosed,
      object: nil,
      userInfo: ["tabId": id]
    )
  }

  func switchToTab(id: UUID) {
    guard tabs.contains(where: { $0.id == id }) else { return }

    let previousId = activeTabId
    activeTabId = id

    // Update last accessed time
    if let index = tabs.firstIndex(where: { $0.id == id }) {
      tabs[index].lastAccessed = Date()
    }

    // Ensure WebView exists
    if webViewPool[id] == nil {
      createWebView(for: id)
      restoreTabContent(id: id)
    }

    // Notify observers
    NotificationCenter.default.post(
      name: .tabSwitched,
      object: nil,
      userInfo: [
        "previousTabId": previousId as Any,
        "newTabId": id
      ]
    )

    saveState()
  }

  // MARK: - WebView Management

  private func createWebView(for tabId: UUID) {
    let configuration = WKWebViewConfiguration()
    // processPool deprecated in iOS 15+ - WebKit handles process sharing automatically
    configuration.websiteDataStore = .default()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self
    webView.allowsBackForwardNavigationGestures = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never

    webViewPool[tabId] = webView

    // Setup scroll position observer
    setupScrollObserver(for: tabId, webView: webView)
  }

  func getWebView(for tabId: UUID) -> WKWebView? {
    if webViewPool[tabId] == nil {
      createWebView(for: tabId)
      restoreTabContent(id: tabId)
    }
    return webViewPool[tabId]
  }

  // MARK: - State Persistence

  func updateTabState(
    id: UUID,
    url: URL? = nil,
    title: String? = nil,
    favicon: UIImage? = nil,
    scrollPosition: ScrollPosition? = nil
  ) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

    if let url = url {
      tabs[index].url = url

      // Add to history
      let historyItem = HistoryItem(url: url, title: title ?? "", visitedAt: Date())
      tabs[index].history.append(historyItem)
      tabs[index].currentHistoryIndex = tabs[index].history.count - 1
    }

    if let title = title {
      tabs[index].title = title
    }

    if let favicon = favicon,
       let data = favicon.pngData() {
      tabs[index].favicon = data
    }

    if let scrollPosition = scrollPosition {
      tabs[index].scrollPosition = scrollPosition
    }

    saveState()
  }

  func updateNavigationState(id: UUID, canGoBack: Bool, canGoForward: Bool) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

    tabs[index].canGoBack = canGoBack
    tabs[index].canGoForward = canGoForward
  }

  func updateLoadingState(id: UUID, isLoading: Bool, progress: Double) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

    tabs[index].isLoading = isLoading
    tabs[index].estimatedProgress = progress
  }

  // MARK: - Scroll Position Tracking

  private func setupScrollObserver(for tabId: UUID, webView: WKWebView) {
    let scrollView = webView.scrollView
    let publisher = scrollView.publisher(for: \.contentOffset)

    scrollObservers[tabId] = publisher
      .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
      .sink { [weak self] offset in
        self?.updateScrollPosition(tabId: tabId, offset: offset)
      }
  }

  private func updateScrollPosition(tabId: UUID, offset: CGPoint) {
    guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }

    tabs[index].scrollPosition = ScrollPosition(x: offset.x, y: offset.y)
  }

  private func restoreScrollPosition(for tabId: UUID) {
    guard let webView = webViewPool[tabId],
          let tab = tabs.first(where: { $0.id == tabId }) else { return }

    let scrollPosition = tab.scrollPosition
    let scrollPoint = CGPoint(x: scrollPosition.x, y: scrollPosition.y)

    webView.scrollView.setContentOffset(scrollPoint, animated: false)
  }

  // MARK: - Content Restoration

  private func restoreTabContent(id: UUID) {
    guard let tab = tabs.first(where: { $0.id == id }),
          let webView = webViewPool[id] else { return }

    // Restore URL
    if let url = tab.url {
      let request = URLRequest(url: url)
      webView.load(request)
    }

    // Restore cookies if available
    if let cookiesData = tab.cookiesData,
       let cookies = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: cookiesData) as? [HTTPCookie] {
      let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
      cookies.forEach { cookie in
        cookieStore.setCookie(cookie)
      }
    }

    // Restore scroll position after page loads
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.restoreScrollPosition(for: id)
    }
  }

  // MARK: - Persistence

  private func saveState() {
    // Filter out transient data
    let persistableTabs = tabs.map { tab -> TabState in
      var cleanTab = tab
      cleanTab.pageHTML = nil // Don't persist HTML
      cleanTab.isLoading = false
      cleanTab.estimatedProgress = 0
      return cleanTab
    }

    if let encoded = try? JSONEncoder().encode(persistableTabs) {
      UserDefaults.standard.set(encoded, forKey: stateArchiveKey)
      UserDefaults.standard.set(activeTabId?.uuidString, forKey: "\(stateArchiveKey)_active")
    }
  }

  private func loadPersistedState() {
    guard let data = UserDefaults.standard.data(forKey: stateArchiveKey),
          let decodedTabs = try? JSONDecoder().decode([TabState].self, from: data) else {
      return
    }

    tabs = decodedTabs

    if let activeIdString = UserDefaults.standard.string(forKey: "\(stateArchiveKey)_active"),
       let activeId = UUID(uuidString: activeIdString),
       tabs.contains(where: { $0.id == activeId }) {
      activeTabId = activeId
    } else {
      activeTabId = tabs.first?.id
    }
  }

  // MARK: - Memory Management

  private func setupMemoryMonitoring() {
    memoryPressureObserver = NotificationCenter.default
      .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
      .sink { [weak self] _ in
        self?.handleMemoryPressure()
      }
  }

  private func handleMemoryPressure() {
    print("Memory pressure detected - cleaning up inactive tabs")

    // Keep only active tab's WebView
    guard let activeId = activeTabId else { return }

    for (tabId, webView) in webViewPool where tabId != activeId {
      webView.stopLoading()
      webView.navigationDelegate = nil
      webViewPool.removeValue(forKey: tabId)
    }

    // Cancel non-active scroll observers
    for (tabId, observer) in scrollObservers where tabId != activeId {
      observer.cancel()
      scrollObservers.removeValue(forKey: tabId)
    }
  }

  // MARK: - Public Accessors

  var activeTab: TabState? {
    guard let id = activeTabId else { return nil }
    return tabs.first(where: { $0.id == id })
  }

  var tabCount: Int {
    return tabs.count
  }

  func getTab(id: UUID) -> TabState? {
    return tabs.first(where: { $0.id == id })
  }

  func getAllTabs() -> [TabState] {
    return tabs
  }
}

// MARK: - WKNavigationDelegate

extension TabStateManager: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    guard let tabId = webViewPool.first(where: { $0.value === webView })?.key else { return }
    updateLoadingState(id: tabId, isLoading: true, progress: 0.1)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard let tabId = webViewPool.first(where: { $0.value === webView })?.key else { return }

    updateLoadingState(id: tabId, isLoading: false, progress: 1.0)
    updateTabState(
      id: tabId,
      url: webView.url,
      title: webView.title
    )
    updateNavigationState(
      id: tabId,
      canGoBack: webView.canGoBack,
      canGoForward: webView.canGoForward
    )

    // Extract favicon
    extractFavicon(from: webView, for: tabId)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    guard let tabId = webViewPool.first(where: { $0.value === webView })?.key else { return }
    updateLoadingState(id: tabId, isLoading: false, progress: 0)
  }

  private func extractFavicon(from webView: WKWebView, for tabId: UUID) {
    let js = """
      var link = document.querySelector("link[rel*='icon']");
      link ? link.href : null;
    """

    webView.evaluateJavaScript(js) { [weak self] result, _ in
      if let urlString = result as? String,
         let url = URL(string: urlString) {
        self?.downloadFavicon(from: url, for: tabId)
      }
    }
  }

  private func downloadFavicon(from url: URL, for tabId: UUID) {
    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let data = data,
            let image = UIImage(data: data) else { return }

      DispatchQueue.main.async {
        self?.updateTabState(id: tabId, favicon: image)
      }
    }.resume()
  }
}

// MARK: - Notification Names

extension Notification.Name {
  static let tabCreated = Notification.Name("tabStateCreated")
  static let tabClosed = Notification.Name("tabStateClosed")
  static let tabSwitched = Notification.Name("tabStateSwitched")
  static let tabStateUpdated = Notification.Name("tabStateUpdated")
}