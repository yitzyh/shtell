//
//  TabSwitchAnimator.swift
//  DumFlow
//
//  Created by Tab 4 - Horizontal Navigation
//  TestFlight 2.1.0 Sprint
//

import SwiftUI
import WebKit

/// Manages smooth 0.3s slide animations for tab transitions
/// Provides Safari-style visual effects during tab switching
class TabSwitchAnimator: ObservableObject {
  // MARK: - Animation Properties
  @Published var currentAnimation: TabAnimation = .none
  @Published var animationProgress: CGFloat = 0
  @Published var isAnimating: Bool = false

  // Visual effects
  @Published var blurRadius: CGFloat = 0
  @Published var scaleEffect: CGFloat = 1.0
  @Published var opacity: Double = 1.0

  // Configuration
  let animationDuration: TimeInterval = 0.3
  let springResponse: CGFloat = 0.35
  let springDamping: CGFloat = 0.85

  // MARK: - Animation Types

  enum TabAnimation: Equatable {
    case none
    case slideLeft
    case slideRight
    case fadeTransition
    case scaleAndFade
    case elasticBounce
  }

  enum TransitionDirection {
    case forward
    case backward
    case instant
  }

  // MARK: - Transition Methods

  func animateTabSwitch(
    from fromIndex: Int,
    to toIndex: Int,
    completion: @escaping () -> Void
  ) {
    guard fromIndex != toIndex else {
      completion()
      return
    }

    let direction: TransitionDirection = toIndex > fromIndex ? .forward : .backward

    // Prepare animation state
    isAnimating = true
    currentAnimation = direction == .forward ? .slideLeft : .slideRight

    // Start visual effects
    startTransitionEffects(direction: direction)

    // Perform main animation
    withAnimation(.easeInOut(duration: animationDuration)) {
      animationProgress = 1.0
    }

    // Complete animation
    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
      self.completeAnimation(completion: completion)
    }
  }

  // MARK: - Visual Effects

  private func startTransitionEffects(direction: TransitionDirection) {
    // Apply blur during transition
    withAnimation(.easeIn(duration: animationDuration * 0.3)) {
      blurRadius = 2.0
    }

    // Scale effect for depth perception
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
      scaleEffect = direction == .forward ? 0.95 : 1.05
    }

    // Fade effect
    withAnimation(.linear(duration: animationDuration * 0.5)) {
      opacity = 0.8
    }

    // Restore effects at midpoint
    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.5) {
      self.restoreVisualEffects()
    }
  }

  private func restoreVisualEffects() {
    withAnimation(.easeOut(duration: animationDuration * 0.5)) {
      blurRadius = 0
      scaleEffect = 1.0
      opacity = 1.0
    }
  }

  // MARK: - Animation Completion

  private func completeAnimation(completion: @escaping () -> Void) {
    // Reset animation state
    animationProgress = 0
    currentAnimation = .none
    isAnimating = false

    // Ensure visual effects are reset
    blurRadius = 0
    scaleEffect = 1.0
    opacity = 1.0

    completion()
  }

  // MARK: - Special Animations

  func animateNewTabCreation(completion: @escaping () -> Void) {
    isAnimating = true
    currentAnimation = .scaleAndFade

    // Zoom and fade in effect
    scaleEffect = 0.8
    opacity = 0

    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
      scaleEffect = 1.0
      opacity = 1.0
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
      self.completeAnimation(completion: completion)
    }
  }

  func animateTabClosure(at index: Int, completion: @escaping () -> Void) {
    isAnimating = true
    currentAnimation = .fadeTransition

    // Fade out and scale down
    withAnimation(.easeInOut(duration: animationDuration * 0.8)) {
      opacity = 0
      scaleEffect = 0.9
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.8) {
      self.completeAnimation(completion: completion)
    }
  }

  func animateElasticBounce() {
    currentAnimation = .elasticBounce

    withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
      scaleEffect = 1.1
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
        self.scaleEffect = 1.0
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.currentAnimation = .none
    }
  }

  // MARK: - Animation Offset Calculations

  func calculateOffset(for index: Int, current: Int, screenWidth: CGFloat) -> CGFloat {
    guard isAnimating else {
      return index == current ? 0 : (index < current ? -screenWidth : screenWidth)
    }

    switch currentAnimation {
    case .slideLeft:
      if index == current {
        return -screenWidth * animationProgress
      } else if index == current + 1 {
        return screenWidth * (1 - animationProgress)
      }

    case .slideRight:
      if index == current {
        return screenWidth * animationProgress
      } else if index == current - 1 {
        return -screenWidth * (1 - animationProgress)
      }

    default:
      break
    }

    // Default: keep tabs off-screen
    return index < current ? -screenWidth : screenWidth
  }

  // MARK: - Gesture Integration

  func updateFromGesture(offset: CGFloat, screenWidth: CGFloat) {
    // Convert drag offset to animation progress
    let progress = abs(offset) / screenWidth
    animationProgress = min(progress, 1.0)

    // Apply subtle visual effects based on gesture
    let effectIntensity = progress * 0.5
    blurRadius = effectIntensity * 2
    scaleEffect = 1.0 - (effectIntensity * 0.05)
    opacity = 1.0 - (effectIntensity * 0.2)
  }

  func cancelGesture() {
    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
      animationProgress = 0
      blurRadius = 0
      scaleEffect = 1.0
      opacity = 1.0
    }
    currentAnimation = .none
  }
}

// MARK: - SwiftUI View Extensions

struct TabTransitionModifier: ViewModifier {
  @ObservedObject var animator: TabSwitchAnimator
  let tabIndex: Int
  let currentIndex: Int
  let screenWidth: CGFloat

  func body(content: Content) -> some View {
    content
      .offset(x: animator.calculateOffset(
        for: tabIndex,
        current: currentIndex,
        screenWidth: screenWidth
      ))
      .scaleEffect(animator.scaleEffect)
      .opacity(animator.opacity)
      .blur(radius: animator.blurRadius)
      .animation(
        .spring(
          response: animator.springResponse,
          dampingFraction: animator.springDamping
        ),
        value: animator.animationProgress
      )
  }
}

// MARK: - Animation View Container

struct AnimatedTabContainer<Content: View>: View {
  @ObservedObject var animator: TabSwitchAnimator
  @ObservedObject var gestureHandler: HorizontalGestureHandler
  let content: () -> Content

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ForEach(0..<gestureHandler.tabCount, id: \.self) { index in
          TabContentView(index: index) {
            content()
          }
          .modifier(TabTransitionModifier(
            animator: animator,
            tabIndex: index,
            currentIndex: gestureHandler.currentTabIndex,
            screenWidth: geometry.size.width
          ))
          .zIndex(index == gestureHandler.currentTabIndex ? 1 : 0)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
  }
}

// MARK: - Individual Tab View

struct TabContentView<Content: View>: View {
  let index: Int
  let content: () -> Content

  var body: some View {
    content()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .tag(index)
  }
}

// MARK: - Preview Helper

#if DEBUG
struct TabSwitchAnimator_Previews: PreviewProvider {
  static var previews: some View {
    AnimatedTabContainer(
      animator: TabSwitchAnimator(),
      gestureHandler: HorizontalGestureHandler()
    ) {
      Color.blue
        .overlay(
          Text("Tab Content")
            .foregroundColor(.white)
        )
    }
  }
}
#endif