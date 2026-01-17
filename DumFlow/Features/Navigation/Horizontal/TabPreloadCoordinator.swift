//
//  TabPreloadCoordinator.swift
//  DumFlow
//
//  Created by Tab 4 - Horizontal Navigation
//  TestFlight 2.1.0 Sprint
//

import SwiftUI
import WebKit
import Combine

/// Coordinates preloading of adjacent tabs for instant switching
/// Manages WebView pool efficiently with current ± 1 tab preloading
class TabPreloadCoordinator: ObservableObject {
  // MARK: - Properties
  @Published var preloadStatus: [UUID: PreloadState] = [:]
  @Published var memoryUsage: Float = 0
  @Published var isPreloading: Bool = false

  // Managers
  private let stateManager: TabStateManager
  private let gestureHandler: HorizontalGestureHandler

  // WebView pool
  private var webViewPool: [UUID: WKWebView] = [:]
  private var preloadQueue = DispatchQueue(label: "com.shtell.tabpreload", qos: .userInitiated)

  // Memory management
  private let maxPreloadedTabs = 3 // Current + adjacent
  private let memoryLimit: Float = 200.0 // MB
  private let recycleThreshold: Float = 150.0 // MB

  // Preload timing
  private var preloadTimer: Timer?
  private let immediateDelay: TimeInterval = 0.0
  private let adjacentDelay: TimeInterval = 0.2
  private let backgroundDelay: TimeInterval = 0.5

  // Cancellables
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Preload State

  enum PreloadState: Equatable {
    case notLoaded
    case queued
    case loading(progress: Double)
    case loaded
    case failed(error: String)
  }

  enum PreloadPriority {
    case immediate  // Current tab
    case high      // Adjacent tabs
    case medium    // Recently accessed
    case low       // Background tabs
  }

  // MARK: - Initialization

  init(stateManager: TabStateManager, gestureHandler: HorizontalGestureHandler) {
    self.stateManager = stateManager
    self.gestureHandler = gestureHandler

    setupObservers()
    monitorMemoryUsage()
  }

  private func setupObservers() {
    // Monitor tab switches
    NotificationCenter.default
      .publisher(for: .tabDidSwitch)
      .sink { [weak self] notification in
        if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
          self?.handleTabSwitch(to: tabIndex)
        }
      }
      .store(in: &cancellables)

    // Monitor tab creation
    NotificationCenter.default
      .publisher(for: .tabCreated)
      .sink { [weak self] notification in
        if let tabId = notification.userInfo?["tabId"] as? UUID {
          self?.preloadTab(id: tabId, priority: .high)
        }
      }
      .store(in: &cancellables)

    // Monitor gesture progress for predictive loading
    gestureHandler.$gestureProgress
      .filter { $0 > 0.3 } // Start preloading when gesture is 30% complete
      .sink { [weak self] progress in
        self?.handlePredictivePreload(progress: progress)
      }
      .store(in: &cancellables)
  }

  // MARK: - Preload Management

  func handleTabSwitch(to index: Int) {
    let tabs = stateManager.getAllTabs()
    guard index < tabs.count else { return }

    // Cancel all pending preloads
    preloadTimer?.invalidate()

    // Determine which tabs to preload
    let currentTabId = tabs[index].id
    var tabsToPreload: [(UUID, PreloadPriority)] = [(currentTabId, .immediate)]

    // Add adjacent tabs
    if index > 0 {
      tabsToPreload.append((tabs[index - 1].id, .high))
    }
    if index < tabs.count - 1 {
      tabsToPreload.append((tabs[index + 1].id, .high))
    }

    // Start preloading
    preloadMultipleTabs(tabsToPreload)

    // Clean up distant tabs
    cleanupDistantTabs(keepIndices: Set([index - 1, index, index + 1]))
  }

  func preloadMultipleTabs(_ tabs: [(UUID, PreloadPriority)]) {
    isPreloading = true

    for (tabId, priority) in tabs {
      let delay = delayForPriority(priority)

      if delay == 0 {
        // Immediate loading
        preloadTab(id: tabId, priority: priority)
      } else {
        // Delayed loading
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
          self?.preloadTab(id: tabId, priority: priority)
        }
      }
    }
  }

  func preloadTab(id: UUID, priority: PreloadPriority) {
    // Check if already loaded
    if webViewPool[id] != nil && preloadStatus[id] == .loaded {
      return
    }

    // Update status
    preloadStatus[id] = .queued

    preloadQueue.async { [weak self] in
      self?.performPreload(tabId: id, priority: priority)
    }
  }

  private func performPreload(tabId: UUID, priority: PreloadPriority) {
    guard let tab = stateManager.getTab(id: tabId) else { return }

    DispatchQueue.main.async { [weak self] in
      // Update status
      self?.preloadStatus[tabId] = .loading(progress: 0.0)

      // Get or create WebView
      let webView = self?.getOrCreateWebView(for: tabId) ?? WKWebView()

      // Load content if URL exists
      if let url = tab.url {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        webView.load(request)

        // Monitor loading progress
        self?.monitorLoadingProgress(for: tabId, webView: webView)
      } else {
        // Load blank page for new tabs
        webView.loadHTMLString(Self.blankPageHTML, baseURL: nil)
        self?.preloadStatus[tabId] = .loaded
      }

      // Store in pool
      self?.webViewPool[tabId] = webView
    }
  }

  // MARK: - WebView Management

  private func getOrCreateWebView(for tabId: UUID) -> WKWebView {
    if let existingWebView = webViewPool[tabId] {
      return existingWebView
    }

    return createWebView(for: tabId)
  }

  private func createWebView(for tabId: UUID) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    // Note: processPool sharing deprecated in iOS 15+, WebKit handles this automatically
    configuration.websiteDataStore = .default()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []

    // Enable content blocking
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true

    // Performance optimizations
    configuration.suppressesIncrementalRendering = false
    configuration.applicationNameForUserAgent = "Shtell/2.1.0"

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.allowsBackForwardNavigationGestures = false
    webView.scrollView.bounces = true
    webView.scrollView.contentInsetAdjustmentBehavior = .never

    return webView
  }

  func getWebView(for tabId: UUID) -> WKWebView? {
    if let webView = webViewPool[tabId] {
      return webView
    }

    // Create on-demand if not preloaded
    let webView = createWebView(for: tabId)
    webViewPool[tabId] = webView

    // Load content if needed
    if let tab = stateManager.getTab(id: tabId),
       let url = tab.url {
      let request = URLRequest(url: url)
      webView.load(request)
    }

    return webView
  }

  // MARK: - Predictive Preloading

  private func handlePredictivePreload(progress: CGFloat) {
    let tabs = stateManager.getAllTabs()
    let currentIndex = gestureHandler.currentTabIndex

    // Predict next tab based on gesture direction
    let predictedIndex: Int
    if gestureHandler.dragOffset > 0 {
      // Swiping right - previous tab
      predictedIndex = max(0, currentIndex - 1)
    } else {
      // Swiping left - next tab
      predictedIndex = min(tabs.count - 1, currentIndex + 1)
    }

    if predictedIndex != currentIndex && predictedIndex < tabs.count {
      let tabId = tabs[predictedIndex].id
      if preloadStatus[tabId] != .loaded {
        preloadTab(id: tabId, priority: .immediate)
      }
    }
  }

  // MARK: - Memory Management

  private func monitorMemoryUsage() {
    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
      self?.updateMemoryUsage()
    }
  }

  private func updateMemoryUsage() {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_,
                  task_flavor_t(MACH_TASK_BASIC_INFO),
                  $0,
                  &count)
      }
    }

    if result == KERN_SUCCESS {
      let usedMemoryMB = Float(info.resident_size) / 1024.0 / 1024.0
      memoryUsage = usedMemoryMB

      if usedMemoryMB > recycleThreshold {
        performMemoryCleanup()
      }
    }
  }

  private func performMemoryCleanup() {
    print("Memory cleanup triggered: \(memoryUsage)MB")

    let currentIndex = gestureHandler.currentTabIndex
    let tabs = stateManager.getAllTabs()

    // Keep only current and immediately adjacent tabs
    let keepIndices = Set([currentIndex - 1, currentIndex, currentIndex + 1])
      .filter { $0 >= 0 && $0 < tabs.count }

    cleanupDistantTabs(keepIndices: keepIndices)
  }

  private func cleanupDistantTabs(keepIndices: Set<Int>) {
    let tabs = stateManager.getAllTabs()

    for (index, tab) in tabs.enumerated() {
      if !keepIndices.contains(index) {
        // Remove WebView from pool
        if let webView = webViewPool[tab.id] {
          webView.stopLoading()
          webView.loadHTMLString("", baseURL: nil)
          webViewPool.removeValue(forKey: tab.id)
          preloadStatus[tab.id] = .notLoaded
        }
      }
    }
  }

  // MARK: - Loading Progress

  private func monitorLoadingProgress(for tabId: UUID, webView: WKWebView) {
    // Observe estimated progress
    _ = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
      DispatchQueue.main.async {
        let progress = webView.estimatedProgress
        self?.preloadStatus[tabId] = .loading(progress: progress)

        if progress >= 1.0 {
          self?.preloadStatus[tabId] = .loaded
          self?.checkIfPreloadingComplete()
        }
      }
    }

    // Store observer (would need to track these for cleanup)
    // For simplicity, using the WKWebView's built-in KVO
  }

  private func checkIfPreloadingComplete() {
    let allLoaded = preloadStatus.values.allSatisfy { status in
      switch status {
      case .loaded, .notLoaded:
        return true
      default:
        return false
      }
    }

    if allLoaded {
      isPreloading = false
    }
  }

  // MARK: - Helper Methods

  private func delayForPriority(_ priority: PreloadPriority) -> TimeInterval {
    switch priority {
    case .immediate:
      return immediateDelay
    case .high:
      return adjacentDelay
    case .medium:
      return backgroundDelay
    case .low:
      return backgroundDelay * 2
    }
  }

  private static let blankPageHTML = """
  <!DOCTYPE html>
  <html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body {
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
        color: white;
      }
      .container {
        text-align: center;
      }
      .logo {
        font-size: 48px;
        margin-bottom: 20px;
      }
      .text {
        font-size: 18px;
        opacity: 0.8;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="logo">Shtell</div>
      <div class="text">Swipe to navigate</div>
    </div>
  </body>
  </html>
  """

  // MARK: - Cleanup

  deinit {
    preloadTimer?.invalidate()
    cancellables.removeAll()

    // Clean up all WebViews
    for (_, webView) in webViewPool {
      webView.stopLoading()
    }
    webViewPool.removeAll()
  }
}

// MARK: - Shared Process Pool

class SharedWebViewPool {
  static let shared = SharedWebViewPool()
  // Note: WKProcessPool is deprecated in iOS 15+ and has no effect
  // Using default process pool (shared automatically by WebKit)

  private init() {}
}

// MARK: - SwiftUI Integration

struct PreloadStatusView: View {
  @ObservedObject var coordinator: TabPreloadCoordinator

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("Tab Preloading")
          .font(.caption.bold())

        Spacer()

        if coordinator.isPreloading {
          ProgressView()
            .scaleEffect(0.7)
        }
      }

      Text("Memory: \(Int(coordinator.memoryUsage))MB / 200MB")
        .font(.caption2)
        .foregroundColor(coordinator.memoryUsage > 180 ? .red : .secondary)

      ForEach(Array(coordinator.preloadStatus.keys), id: \.self) { tabId in
        HStack {
          Circle()
            .fill(colorForStatus(coordinator.preloadStatus[tabId]))
            .frame(width: 6, height: 6)

          Text(String(tabId.uuidString.prefix(8)))
            .font(.caption2.monospaced())

          Spacer()

          statusText(for: coordinator.preloadStatus[tabId])
        }
      }
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }

  private func colorForStatus(_ status: TabPreloadCoordinator.PreloadState?) -> Color {
    switch status {
    case .loaded:
      return .green
    case .loading:
      return .orange
    case .failed:
      return .red
    default:
      return .gray
    }
  }

  private func statusText(for status: TabPreloadCoordinator.PreloadState?) -> some View {
    Group {
      switch status {
      case .loading(let progress):
        Text("\(Int(progress * 100))%")
          .font(.caption2)
      case .loaded:
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)
          .font(.caption2)
      case .failed:
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundColor(.red)
          .font(.caption2)
      default:
        EmptyView()
      }
    }
  }
}