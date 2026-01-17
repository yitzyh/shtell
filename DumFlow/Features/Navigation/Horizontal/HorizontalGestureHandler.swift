//
//  HorizontalGestureHandler.swift
//  DumFlow
//
//  Created by Tab 4 - Horizontal Navigation
//  TestFlight 2.1.0 Sprint
//

import SwiftUI
import WebKit

/// Handles horizontal swipe gestures for tab switching
/// Swipe left → Next tab, Swipe right → Previous tab
class HorizontalGestureHandler: ObservableObject {
  // MARK: - Properties
  @Published var currentTabIndex: Int = 0
  @Published var isGestureActive: Bool = false
  @Published var dragOffset: CGFloat = 0
  @Published var gestureProgress: CGFloat = 0

  // Configuration
  let maxTabs = 5
  let switchThreshold: CGFloat = 100
  let velocityThreshold: CGFloat = 800
  let hapticFeedback = UIImpactFeedbackGenerator(style: .light)

  // Gesture state
  private var startLocation: CGPoint = .zero
  private var startTime: Date = Date()
  private var tabs: [TabInfo] = []

  // MARK: - Tab Management
  struct TabInfo {
    let id: UUID
    var url: URL?
    var title: String
    var favicon: UIImage?
    var scrollPosition: CGPoint
    var canGoBack: Bool
    var canGoForward: Bool
  }

  init() {
    // Initialize with one default tab
    tabs = [TabInfo(
      id: UUID(),
      url: nil,
      title: "New Tab",
      favicon: nil,
      scrollPosition: .zero,
      canGoBack: false,
      canGoForward: false
    )]
    hapticFeedback.prepare()
  }

  // MARK: - Gesture Handling

  func handleDragStart(location: CGPoint) {
    startLocation = location
    startTime = Date()
    isGestureActive = true
    hapticFeedback.prepare()
  }

  func handleDragChange(translation: CGSize, screenWidth: CGFloat) {
    guard isGestureActive else { return }

    dragOffset = translation.width

    // Calculate progress (0 to 1) for animation
    let progress = abs(translation.width) / screenWidth
    gestureProgress = min(progress, 1.0)

    // Provide haptic feedback at threshold
    if abs(translation.width) >= switchThreshold && !hasProvidedFeedback {
      hapticFeedback.impactOccurred(intensity: 0.7)
      hasProvidedFeedback = true
    }
  }

  private var hasProvidedFeedback = false

  func handleDragEnd(translation: CGSize, velocity: CGSize) {
    guard isGestureActive else { return }

    let horizontalVelocity = velocity.width
    let horizontalDistance = translation.width

    // Determine if we should switch tabs
    let shouldSwitch = abs(horizontalDistance) >= switchThreshold ||
                       abs(horizontalVelocity) >= velocityThreshold

    if shouldSwitch {
      if horizontalDistance > 0 {
        // Swipe right - go to previous tab
        switchToPreviousTab()
      } else {
        // Swipe left - go to next tab
        switchToNextTab()
      }
    }

    // Reset gesture state
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      dragOffset = 0
      gestureProgress = 0
    }

    isGestureActive = false
    hasProvidedFeedback = false
  }

  // MARK: - Tab Switching

  func switchToNextTab() {
    guard currentTabIndex < tabs.count - 1 else {
      // Create new tab if at the end and under max
      if tabs.count < maxTabs {
        createNewTab()
      }
      return
    }

    withAnimation(.easeInOut(duration: 0.3)) {
      currentTabIndex += 1
    }

    hapticFeedback.impactOccurred()
    notifyTabSwitch()
  }

  func switchToPreviousTab() {
    guard currentTabIndex > 0 else {
      // Elastic bounce at beginning
      elasticBounce()
      return
    }

    withAnimation(.easeInOut(duration: 0.3)) {
      currentTabIndex -= 1
    }

    hapticFeedback.impactOccurred()
    notifyTabSwitch()
  }

  func switchToTab(at index: Int) {
    guard index >= 0 && index < tabs.count else { return }

    withAnimation(.easeInOut(duration: 0.3)) {
      currentTabIndex = index
    }

    notifyTabSwitch()
  }

  // MARK: - Tab Creation & Deletion

  func createNewTab() {
    guard tabs.count < maxTabs else { return }

    let newTab = TabInfo(
      id: UUID(),
      url: nil,
      title: "New Tab",
      favicon: nil,
      scrollPosition: .zero,
      canGoBack: false,
      canGoForward: false
    )

    tabs.append(newTab)

    withAnimation(.easeInOut(duration: 0.3)) {
      currentTabIndex = tabs.count - 1
    }

    hapticFeedback.impactOccurred()
  }

  func closeTab(at index: Int) {
    guard tabs.count > 1 && index < tabs.count else { return }

    tabs.remove(at: index)

    // Adjust current index if needed
    if currentTabIndex >= tabs.count {
      currentTabIndex = tabs.count - 1
    } else if currentTabIndex > index {
      currentTabIndex -= 1
    }

    notifyTabSwitch()
  }

  // MARK: - Tab State Updates

  func updateTabInfo(url: URL?, title: String?, favicon: UIImage?) {
    guard currentTabIndex < tabs.count else { return }

    if let url = url {
      tabs[currentTabIndex].url = url
    }

    if let title = title {
      tabs[currentTabIndex].title = title
    }

    if let favicon = favicon {
      tabs[currentTabIndex].favicon = favicon
    }
  }

  func updateScrollPosition(_ position: CGPoint) {
    guard currentTabIndex < tabs.count else { return }
    tabs[currentTabIndex].scrollPosition = position
  }

  func updateNavigationState(canGoBack: Bool, canGoForward: Bool) {
    guard currentTabIndex < tabs.count else { return }
    tabs[currentTabIndex].canGoBack = canGoBack
    tabs[currentTabIndex].canGoForward = canGoForward
  }

  // MARK: - Helper Methods

  private func elasticBounce() {
    withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
      dragOffset = 50
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
        self.dragOffset = 0
      }
    }

    hapticFeedback.impactOccurred(intensity: 0.5)
  }

  private func notifyTabSwitch() {
    NotificationCenter.default.post(
      name: .tabDidSwitch,
      object: nil,
      userInfo: ["tabIndex": currentTabIndex, "tabId": tabs[currentTabIndex].id]
    )
  }

  // MARK: - Public Accessors

  var currentTab: TabInfo? {
    guard currentTabIndex < tabs.count else { return nil }
    return tabs[currentTabIndex]
  }

  var allTabs: [TabInfo] {
    return tabs
  }

  var tabCount: Int {
    return tabs.count
  }

  var canCreateNewTab: Bool {
    return tabs.count < maxTabs
  }
}

// MARK: - Notification Names

extension Notification.Name {
  static let tabDidSwitch = Notification.Name("tabDidSwitch")
  static let tabDidCreate = Notification.Name("tabDidCreate")
  static let tabDidClose = Notification.Name("tabDidClose")
}

// MARK: - SwiftUI View Modifier

struct HorizontalTabGesture: ViewModifier {
  @ObservedObject var handler: HorizontalGestureHandler
  let screenWidth: CGFloat

  func body(content: Content) -> some View {
    content
      .offset(x: handler.dragOffset * 0.3) // Parallax effect
      .gesture(
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
          .onChanged { value in
            if abs(value.translation.width) > abs(value.translation.height) {
              // Horizontal gesture detected
              handler.handleDragChange(
                translation: value.translation,
                screenWidth: screenWidth
              )
            }
          }
          .onEnded { value in
            handler.handleDragEnd(
              translation: value.translation,
              velocity: CGSize(
                width: value.predictedEndTranslation.width / 0.3,
                height: 0
              )
            )
          }
      )
  }
}

extension View {
  func horizontalTabNavigation(handler: HorizontalGestureHandler) -> some View {
    GeometryReader { geometry in
      self.modifier(HorizontalTabGesture(
        handler: handler,
        screenWidth: geometry.size.width
      ))
    }
  }
}