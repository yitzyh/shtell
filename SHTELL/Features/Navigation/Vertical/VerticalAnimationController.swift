//
//  VerticalAnimationController.swift
//  Shtell
//
//  Created for TestFlight 2.1.0 - TikTok-style vertical navigation
//

import SwiftUI

/// Controls TikTok-style snap animations for vertical navigation
class VerticalAnimationController: ObservableObject {

  // MARK: - Constants

  /// Animation duration (EXACTLY like TikTok)
  static let snapDuration: Double = 0.25

  /// Spring response for snap animation
  static let springResponse: Double = 0.25

  /// Spring damping fraction (critical damping = 1.0)
  static let springDamping: Double = 0.85

  /// Edge bounce animation duration
  static let bounceDuration: Double = 0.4

  /// Maximum edge bounce distance
  static let maxBounceDistance: CGFloat = 30.0

  // MARK: - Animation Types

  enum AnimationType {
    case snap          // Standard navigation snap
    case edgeBounce    // Bounce at queue boundaries
    case cancel        // Return to original position
  }

  // MARK: - Published Properties

  /// Current animation offset
  @Published var animationOffset: CGFloat = 0

  /// Whether animation is currently running
  @Published var isAnimating: Bool = false

  // MARK: - Animation Methods

  /// Animate page transition with TikTok-style snap
  /// - Parameters:
  ///   - direction: Navigation direction (1 = next, -1 = previous)
  ///   - screenHeight: Screen height for full-screen transition
  ///   - completion: Callback when animation completes
  func animatePageTransition(direction: Int, screenHeight: CGFloat, completion: @escaping () -> Void) {
    isAnimating = true

    let targetOffset = CGFloat(direction) * screenHeight

    withAnimation(.spring(response: Self.springResponse, dampingFraction: Self.springDamping)) {
      animationOffset = targetOffset
    }

    // Reset after animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.snapDuration) {
      self.animationOffset = 0
      self.isAnimating = false
      completion()
    }
  }

  /// Animate edge bounce when at queue boundaries
  /// - Parameter direction: Bounce direction (1 = top, -1 = bottom)
  func animateEdgeBounce(direction: Int) {
    isAnimating = true

    let bounceDistance = CGFloat(direction) * Self.maxBounceDistance

    // Bounce out
    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
      animationOffset = bounceDistance
    }

    // Bounce back
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
        self.animationOffset = 0
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + Self.bounceDuration) {
        self.isAnimating = false
      }
    }
  }

  /// Cancel gesture and return to original position
  func animateCancellation() {
    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
      animationOffset = 0
      isAnimating = false
    }
  }

  /// Immediate reset without animation (for state changes)
  func resetImmediate() {
    animationOffset = 0
    isAnimating = false
  }

  // MARK: - Animation Factory

  /// Get appropriate animation for type
  static func animation(for type: AnimationType) -> Animation {
    switch type {
    case .snap:
      return .spring(response: springResponse, dampingFraction: springDamping)

    case .edgeBounce:
      return .spring(response: 0.2, dampingFraction: 0.6)

    case .cancel:
      return .spring(response: 0.2, dampingFraction: 0.8)
    }
  }

  // MARK: - Gesture-to-Animation Bridge

  /// Convert gesture translation to animation offset
  /// - Parameter translation: Current gesture translation
  func updateFromGesture(translation: CGFloat) {
    guard !isAnimating else { return }
    animationOffset = translation
  }

  /// Apply rubber-band effect at edges
  /// - Parameters:
  ///   - translation: Raw gesture translation
  ///   - atEdge: Whether we're at a boundary
  /// - Returns: Dampened translation
  static func rubberBandTranslation(_ translation: CGFloat, atEdge: Bool) -> CGFloat {
    guard atEdge else { return translation }

    // Apply logarithmic dampening
    let sign: CGFloat = translation > 0 ? 1 : -1
    let magnitude = abs(translation)
    let dampened = sign * (log10(1 + magnitude / 100) * 100)

    return dampened
  }
}
