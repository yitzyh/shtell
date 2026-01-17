//
//  ToolbarGestureCoordinator.swift
//  DumFlow
//
//  Created for Shtell v2.1.0
//  Coordinate gestures with Tab 3 & 4 navigation
//

import SwiftUI
import Combine

class ToolbarGestureCoordinator: ObservableObject {
  // MARK: - Published Properties
  @Published var currentGesture: GestureType = .none
  @Published var gestureProgress: CGFloat = 0
  @Published var isInteracting: Bool = false

  // MARK: - Gesture Types
  enum GestureType {
    case none
    case vertical      // From Tab 3
    case horizontal    // From Tab 4
    case toolbar       // Internal toolbar gesture
  }

  // MARK: - Navigation Callbacks
  var onVerticalNavigation: ((NavigationDirection) -> Void)?
  var onHorizontalTabSwitch: ((Int) -> Void)?
  var onToolbarAction: ((ToolbarAction) -> Void)?

  enum NavigationDirection {
    case previous
    case next
  }

  enum ToolbarAction {
    case selectTab(String)
    case addTab
    case closeTab(String)
    case showMenu
  }

  // MARK: - Gesture Integration
  func handleVerticalGesture(translation: CGFloat, velocity: CGFloat, isEnded: Bool) {
    guard currentGesture == .none || currentGesture == .vertical else { return }

    currentGesture = .vertical
    gestureProgress = abs(translation / 100) // Normalize to 0-1

    if isEnded {
      let threshold: CGFloat = 50
      let velocityThreshold: CGFloat = 500

      if translation > threshold || velocity > velocityThreshold {
        onVerticalNavigation?(.previous)
        provideHapticFeedback(.success)
      } else if translation < -threshold || velocity < -velocityThreshold {
        onVerticalNavigation?(.next)
        provideHapticFeedback(.success)
      }

      resetGesture()
    }
  }

  func handleHorizontalGesture(translation: CGFloat, velocity: CGFloat, isEnded: Bool) {
    guard currentGesture == .none || currentGesture == .horizontal else { return }

    currentGesture = .horizontal
    gestureProgress = abs(translation / 100)

    if isEnded {
      let threshold: CGFloat = 75
      let velocityThreshold: CGFloat = 300

      if translation > threshold || velocity > velocityThreshold {
        // Swipe right - previous tab
        onHorizontalTabSwitch?(-1)
        provideHapticFeedback(.selection)
      } else if translation < -threshold || velocity < -velocityThreshold {
        // Swipe left - next tab
        onHorizontalTabSwitch?(1)
        provideHapticFeedback(.selection)
      }

      resetGesture()
    }
  }

  func handleToolbarTap(at location: CGPoint, in geometry: GeometryProxy) {
    // Handle taps on toolbar items
    currentGesture = .toolbar
    isInteracting = true

    // Calculate which item was tapped based on location
    // This would be integrated with actual toolbar layout

    provideHapticFeedback(.selection)
    resetGesture()
  }

  // MARK: - State Management
  private func resetGesture() {
    withAnimation(.easeOut(duration: 0.2)) {
      currentGesture = .none
      gestureProgress = 0
      isInteracting = false
    }
  }

  // MARK: - Haptic Feedback
  private func provideHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let impact = UIImpactFeedbackGenerator(style: style)
    impact.prepare()
    impact.impactOccurred()
  }

  private func provideHapticFeedback(_ type: HapticType) {
    switch type {
    case .selection:
      let selection = UISelectionFeedbackGenerator()
      selection.prepare()
      selection.selectionChanged()
    case .success:
      let notification = UINotificationFeedbackGenerator()
      notification.prepare()
      notification.notificationOccurred(.success)
    case .light:
      let impact = UIImpactFeedbackGenerator(style: .light)
      impact.prepare()
      impact.impactOccurred()
    }
  }

  private enum HapticType {
    case selection
    case success
    case light
  }
}

// MARK: - Gesture Modifier
struct ToolbarGestureModifier: ViewModifier {
  @ObservedObject var coordinator: ToolbarGestureCoordinator

  func body(content: Content) -> some View {
    content
      .gesture(
        DragGesture(minimumDistance: 10)
          .onChanged { value in
            let isVertical = abs(value.translation.height) > abs(value.translation.width)

            if isVertical {
              coordinator.handleVerticalGesture(
                translation: value.translation.height,
                velocity: value.predictedEndTranslation.height / 0.3,
                isEnded: false
              )
            } else {
              coordinator.handleHorizontalGesture(
                translation: value.translation.width,
                velocity: value.predictedEndTranslation.width / 0.3,
                isEnded: false
              )
            }
          }
          .onEnded { value in
            let isVertical = abs(value.translation.height) > abs(value.translation.width)

            if isVertical {
              coordinator.handleVerticalGesture(
                translation: value.translation.height,
                velocity: value.predictedEndTranslation.height / 0.3,
                isEnded: true
              )
            } else {
              coordinator.handleHorizontalGesture(
                translation: value.translation.width,
                velocity: value.predictedEndTranslation.width / 0.3,
                isEnded: true
              )
            }
          }
      )
  }
}

extension View {
  func toolbarGestures(_ coordinator: ToolbarGestureCoordinator) -> some View {
    modifier(ToolbarGestureModifier(coordinator: coordinator))
  }
}