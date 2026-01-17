//
//  VerticalStateManager.swift
//  Shtell
//
//  Created for TestFlight 2.1.0 - TikTok-style vertical navigation
//

import SwiftUI
import Combine

/// Manages navigation state and queue boundaries for vertical navigation
class VerticalStateManager: ObservableObject {

  // MARK: - Navigation Queue

  /// Content queue for vertical navigation
  @Published var contentQueue: [WebPageItem] = []

  /// Current index in the queue
  @Published var currentIndex: Int = 0

  /// Total items in queue
  var queueSize: Int {
    contentQueue.count
  }

  // MARK: - Boundary State

  /// Whether we're at the top of the queue
  var isAtTop: Bool {
    currentIndex <= 0
  }

  /// Whether we're at the bottom of the queue
  var isAtBottom: Bool {
    currentIndex >= contentQueue.count - 1
  }

  /// Whether we can navigate to next item
  var canNavigateNext: Bool {
    !isAtBottom
  }

  /// Whether we can navigate to previous item
  var canNavigatePrevious: Bool {
    !isAtTop
  }

  // MARK: - Current Page

  /// Get current webpage item
  var currentPage: WebPageItem? {
    guard currentIndex >= 0 && currentIndex < contentQueue.count else {
      return nil
    }
    return contentQueue[currentIndex]
  }

  /// Get next webpage item (for preloading)
  var nextPage: WebPageItem? {
    guard canNavigateNext else { return nil }
    return contentQueue[currentIndex + 1]
  }

  /// Get previous webpage item (for preloading)
  var previousPage: WebPageItem? {
    guard canNavigatePrevious else { return nil }
    return contentQueue[currentIndex - 1]
  }

  // MARK: - Navigation Methods

  /// Navigate to next page
  /// - Returns: True if navigation occurred, false if at boundary
  @discardableResult
  func navigateToNext() -> Bool {
    guard canNavigateNext else {
      return false
    }

    currentIndex += 1
    return true
  }

  /// Navigate to previous page
  /// - Returns: True if navigation occurred, false if at boundary
  @discardableResult
  func navigateToPrevious() -> Bool {
    guard canNavigatePrevious else {
      return false
    }

    currentIndex -= 1
    return true
  }

  /// Jump to specific index
  /// - Parameter index: Target index
  /// - Returns: True if jump occurred, false if index invalid
  @discardableResult
  func jumpToIndex(_ index: Int) -> Bool {
    guard index >= 0 && index < contentQueue.count else {
      return false
    }

    currentIndex = index
    return true
  }

  // MARK: - Queue Management

  /// Load initial content queue
  /// - Parameter items: Array of webpage items
  func loadQueue(_ items: [WebPageItem]) {
    contentQueue = items
    currentIndex = 0
  }

  /// Append items to queue
  /// - Parameter items: New items to add
  func appendToQueue(_ items: [WebPageItem]) {
    contentQueue.append(contentsOf: items)
  }

  /// Insert items at current position
  /// - Parameter items: Items to insert
  func insertAtCurrent(_ items: [WebPageItem]) {
    let insertIndex = currentIndex + 1
    contentQueue.insert(contentsOf: items, at: insertIndex)
  }

  /// Remove item at index
  /// - Parameter index: Index to remove
  func removeItem(at index: Int) {
    guard index >= 0 && index < contentQueue.count else { return }

    contentQueue.remove(at: index)

    // Adjust current index if needed
    if currentIndex >= contentQueue.count {
      currentIndex = max(0, contentQueue.count - 1)
    }
  }

  /// Clear entire queue
  func clearQueue() {
    contentQueue.removeAll()
    currentIndex = 0
  }

  // MARK: - Preloading Helpers

  /// Get indices that should be preloaded (current ± 1)
  var preloadIndices: [Int] {
    var indices: [Int] = [currentIndex]

    if canNavigatePrevious {
      indices.append(currentIndex - 1)
    }

    if canNavigateNext {
      indices.append(currentIndex + 1)
    }

    return indices
  }

  /// Get pages that should be preloaded
  var pagesToPreload: [WebPageItem] {
    preloadIndices.compactMap { index in
      guard index >= 0 && index < contentQueue.count else { return nil }
      return contentQueue[index]
    }
  }

  // MARK: - Progress Tracking

  /// Progress through queue (0.0 - 1.0)
  var queueProgress: Double {
    guard contentQueue.count > 1 else { return 0 }
    return Double(currentIndex) / Double(contentQueue.count - 1)
  }

  /// Items remaining in queue
  var itemsRemaining: Int {
    max(0, contentQueue.count - currentIndex - 1)
  }
}

// MARK: - WebPageItem Model

/// Represents a webpage in the navigation queue
struct WebPageItem: Identifiable, Equatable {
  let id: String
  let url: URL
  let title: String?
  let category: String?
  let metadata: [String: String]?

  init(id: String = UUID().uuidString, url: URL, title: String? = nil, category: String? = nil, metadata: [String: String]? = nil) {
    self.id = id
    self.url = url
    self.title = title
    self.category = category
    self.metadata = metadata
  }

  static func == (lhs: WebPageItem, rhs: WebPageItem) -> Bool {
    lhs.id == rhs.id
  }
}
