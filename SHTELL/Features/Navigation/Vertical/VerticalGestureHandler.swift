//
//  VerticalGestureHandler.swift
//  Shtell
//
//  Created for TestFlight 2.1.0 - TikTok-style vertical navigation
//

import SwiftUI
import UIKit

/// Handles pull up/down gestures for vertical navigation between webpages
class VerticalGestureHandler: ObservableObject {

  // MARK: - Constants

  /// Velocity threshold to trigger navigation (pts/sec)
  static let velocityThreshold: CGFloat = 500.0

  /// Distance threshold to trigger navigation (points)
  static let distanceThreshold: CGFloat = 50.0

  // MARK: - Published Properties

  /// Current vertical translation during gesture
  @Published var currentTranslation: CGFloat = 0

  /// Whether a gesture is currently active
  @Published var isGestureActive: Bool = false

  /// Indicates if we should trigger navigation to next page
  @Published var shouldNavigateNext: Bool = false

  /// Indicates if we should trigger navigation to previous page
  @Published var shouldNavigatePrevious: Bool = false

  // MARK: - Private Properties

  private var startTranslation: CGFloat = 0
  private var lastVelocity: CGFloat = 0

  // MARK: - Gesture Handling

  /// Process vertical drag gesture
  /// - Parameters:
  ///   - translation: Current translation of the gesture
  ///   - velocity: Current velocity of the gesture
  func handleDragChanged(translation: CGFloat, velocity: CGFloat) {
    isGestureActive = true
    currentTranslation = translation
    lastVelocity = velocity
  }

  /// Handle gesture end and determine if navigation should occur
  func handleDragEnded() {
    defer {
      resetGesture()
    }

    // Check velocity-based trigger
    let isVelocityTriggered = abs(lastVelocity) >= Self.velocityThreshold

    // Check distance-based trigger
    let isDistanceTriggered = abs(currentTranslation) >= Self.distanceThreshold

    // Determine navigation direction
    if isVelocityTriggered || isDistanceTriggered {
      if currentTranslation > 0 {
        // Pull down → Previous page
        shouldNavigatePrevious = true
      } else if currentTranslation < 0 {
        // Pull up → Next page
        shouldNavigateNext = true
      }
    }
  }

  /// Reset gesture state
  private func resetGesture() {
    isGestureActive = false
    currentTranslation = 0
    startTranslation = 0
    lastVelocity = 0
  }

  /// Clear navigation flags after processing
  func clearNavigationFlags() {
    shouldNavigateNext = false
    shouldNavigatePrevious = false
  }

  // MARK: - Gesture Creation

  /// Create SwiftUI DragGesture with proper configuration
  func createDragGesture() -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let translation = value.translation.height
        let velocity = value.predictedEndTranslation.height - value.translation.height
        self.handleDragChanged(translation: translation, velocity: velocity)
      }
      .onEnded { _ in
        self.handleDragEnded()
      }
  }

  // MARK: - Helper Methods

  /// Calculate progress percentage for visual feedback (0-1)
  var gestureProgress: CGFloat {
    guard isGestureActive else { return 0 }
    return min(abs(currentTranslation) / Self.distanceThreshold, 1.0)
  }

  /// Determine if current gesture will trigger navigation
  var willTriggerNavigation: Bool {
    let isVelocityTriggered = abs(lastVelocity) >= Self.velocityThreshold
    let isDistanceTriggered = abs(currentTranslation) >= Self.distanceThreshold
    return isVelocityTriggered || isDistanceTriggered
  }
}
