//
//  VerticalNavigationCoordinator.swift
//  Shtell
//
//  Created for TestFlight 2.1.0 - TikTok-style vertical navigation
//  Integrates gesture handling, animation, and state management
//

import SwiftUI
import Combine

/// Master coordinator for vertical navigation system
class VerticalNavigationCoordinator: ObservableObject {

  // MARK: - Component Dependencies

  @Published var gestureHandler = VerticalGestureHandler()
  @Published var animationController = VerticalAnimationController()
  @Published var stateManager = VerticalStateManager()

  // MARK: - Subscribers

  private var cancellables = Set<AnyCancellable>()

  // MARK: - Screen Dimensions

  private var screenHeight: CGFloat = UIScreen.main.bounds.height

  // MARK: - Initialization

  init() {
    setupSubscribers()
  }

  // MARK: - Subscriber Setup

  private func setupSubscribers() {
    // Listen for navigation triggers from gesture handler
    gestureHandler.$shouldNavigateNext
      .sink { [weak self] shouldNavigate in
        if shouldNavigate {
          self?.handleNavigateNext()
          self?.gestureHandler.clearNavigationFlags()
        }
      }
      .store(in: &cancellables)

    gestureHandler.$shouldNavigatePrevious
      .sink { [weak self] shouldNavigate in
        if shouldNavigate {
          self?.handleNavigatePrevious()
          self?.gestureHandler.clearNavigationFlags()
        }
      }
      .store(in: &cancellables)

    // Sync gesture translation to animation offset
    gestureHandler.$currentTranslation
      .sink { [weak self] translation in
        guard let self = self else { return }

        // Apply rubber-band effect if at edge
        let atEdge = (translation > 0 && self.stateManager.isAtTop) ||
                     (translation < 0 && self.stateManager.isAtBottom)

        let dampened = VerticalAnimationController.rubberBandTranslation(translation, atEdge: atEdge)
        self.animationController.updateFromGesture(translation: dampened)
      }
      .store(in: &cancellables)
  }

  // MARK: - Navigation Handlers

  /// Handle navigation to next page
  private func handleNavigateNext() {
    // Check if we can navigate
    guard stateManager.canNavigateNext else {
      // Trigger edge bounce at bottom
      animationController.animateEdgeBounce(direction: -1)
      return
    }

    // Perform navigation with animation
    animationController.animatePageTransition(direction: -1, screenHeight: screenHeight) {
      // Update state after animation completes
      self.stateManager.navigateToNext()
    }
  }

  /// Handle navigation to previous page
  private func handleNavigatePrevious() {
    // Check if we can navigate
    guard stateManager.canNavigatePrevious else {
      // Trigger edge bounce at top
      animationController.animateEdgeBounce(direction: 1)
      return
    }

    // Perform navigation with animation
    animationController.animatePageTransition(direction: 1, screenHeight: screenHeight) {
      // Update state after animation completes
      self.stateManager.navigateToPrevious()
    }
  }

  // MARK: - Public Interface

  /// Load content queue for vertical navigation
  /// - Parameter items: Array of webpage items
  func loadContent(_ items: [WebPageItem]) {
    stateManager.loadQueue(items)
  }

  /// Get current webpage URL
  var currentURL: URL? {
    stateManager.currentPage?.url
  }

  /// Get current page title
  var currentTitle: String? {
    stateManager.currentPage?.title
  }

  /// Get queue progress (0.0 - 1.0)
  var progress: Double {
    stateManager.queueProgress
  }

  // MARK: - Gesture Integration

  /// Create drag gesture for SwiftUI view
  func createVerticalDragGesture() -> some Gesture {
    gestureHandler.createDragGesture()
  }

  /// Get current vertical offset for view transformation
  var verticalOffset: CGFloat {
    animationController.animationOffset
  }

  /// Whether gesture/animation is active (disable other interactions)
  var isInteracting: Bool {
    gestureHandler.isGestureActive || animationController.isAnimating
  }

  // MARK: - Preloading Support

  /// Get pages that should be preloaded for instant navigation
  var pagesToPreload: [WebPageItem] {
    stateManager.pagesToPreload
  }

  // MARK: - Debug/Testing

  #if DEBUG
  /// Test navigation without gestures (for debugging)
  func debugNavigateNext() {
    handleNavigateNext()
  }

  func debugNavigatePrevious() {
    handleNavigatePrevious()
  }

  func debugLoadSampleContent() {
    let samples = [
      WebPageItem(url: URL(string: "https://example.com/1")!, title: "Page 1", category: "Science"),
      WebPageItem(url: URL(string: "https://example.com/2")!, title: "Page 2", category: "Culture"),
      WebPageItem(url: URL(string: "https://example.com/3")!, title: "Page 3", category: "Tech"),
    ]
    loadContent(samples)
  }
  #endif
}
