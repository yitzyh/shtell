//
//  BottomToolbarView.swift
//  DumFlow
//
//  Created for Shtell v2.1.0
//  Main bottom toolbar with liquid glass effect
//

import SwiftUI

struct BottomToolbarView: View {
  @Binding var tabs: [TabInfo]
  @Binding var selectedTabID: String
  @StateObject private var gestureCoordinator = ToolbarGestureCoordinator()

  // Animation states
  @State private var toolbarOffset: CGFloat = 0
  @State private var toolbarOpacity: Double = 1
  @State private var isExpanded: Bool = false
  @State private var showingMenu: Bool = false

  private let toolbarHeight: CGFloat = 60

  var body: some View {
    VStack(spacing: 0) {
      // Main toolbar content
      HStack(spacing: 0) {
        // Left section - Menu button
        Button(action: toggleMenu) {
          Image(systemName: showingMenu ? "xmark" : "line.3.horizontal")
            .foregroundColor(.primary.opacity(0.8))
            .font(.system(size: 18, weight: .medium))
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
            .rotationEffect(.degrees(showingMenu ? 90 : 0))
            .animation(.spring(response: 0.3), value: showingMenu)
        }
        .padding(.leading, 12)

        // Center section - Favicon scroll view
        FaviconScrollView(
          tabs: $tabs,
          selectedTabID: $selectedTabID
        )
        .frame(maxWidth: .infinity)

        // Right section - Actions
        HStack(spacing: 8) {
          // Share button
          Button(action: shareCurrentPage) {
            Image(systemName: "square.and.arrow.up")
              .foregroundColor(.primary.opacity(0.7))
              .font(.system(size: 16))
              .frame(width: 36, height: 36)
          }

          // More options
          Button(action: showMoreOptions) {
            Image(systemName: "ellipsis")
              .foregroundColor(.primary.opacity(0.7))
              .font(.system(size: 16))
              .frame(width: 36, height: 36)
          }
        }
        .padding(.trailing, 12)
      }
      .frame(height: toolbarHeight)
      .liquidGlass(opacity: 0.92)
      .offset(y: toolbarOffset)
      .opacity(toolbarOpacity)
      .toolbarGestures(gestureCoordinator)
    }
    .onAppear {
      setupGestureHandlers()
      animateIn()
    }
  }

  // MARK: - Gesture Setup
  private func setupGestureHandlers() {
    // Handle vertical navigation from Tab 3
    gestureCoordinator.onVerticalNavigation = { direction in
      withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
        // Visual feedback for navigation
        toolbarOffset = direction == .previous ? -5 : 5
      }
      withAnimation(.spring(response: 0.25, dampingFraction: 0.8).delay(0.1)) {
        toolbarOffset = 0
      }
    }

    // Handle horizontal tab switching from Tab 4
    gestureCoordinator.onHorizontalTabSwitch = { direction in
      switchTab(by: direction)
    }

    // Handle internal toolbar actions
    gestureCoordinator.onToolbarAction = { action in
      handleToolbarAction(action)
    }
  }

  // MARK: - Tab Management
  private func switchTab(by offset: Int) {
    guard let currentIndex = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }

    let newIndex = currentIndex + offset
    if newIndex >= 0 && newIndex < tabs.count {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        selectedTabID = tabs[newIndex].id
      }

      // Pulse animation on tab switch
      withAnimation(.easeInOut(duration: 0.15)) {
        toolbarOpacity = 0.8
      }
      withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
        toolbarOpacity = 1
      }
    }
  }

  private func handleToolbarAction(_ action: ToolbarGestureCoordinator.ToolbarAction) {
    switch action {
    case .selectTab(let tabID):
      selectedTabID = tabID
    case .addTab:
      addNewTab()
    case .closeTab(let tabID):
      closeTab(tabID)
    case .showMenu:
      toggleMenu()
    }
  }

  // MARK: - Actions
  private func toggleMenu() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      showingMenu.toggle()
    }

    // Haptic feedback
    let impact = UIImpactFeedbackGenerator(style: .medium)
    impact.prepare()
    impact.impactOccurred()
  }

  private func shareCurrentPage() {
    // Share functionality
    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.prepare()
    impact.impactOccurred()
  }

  private func showMoreOptions() {
    // More options menu
    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.prepare()
    impact.impactOccurred()
  }

  private func addNewTab() {
    let newTab = TabInfo(
      id: UUID().uuidString,
      url: nil,
      title: "New Tab"
    )
    tabs.append(newTab)
    selectedTabID = newTab.id
  }

  private func closeTab(_ tabID: String) {
    tabs.removeAll { $0.id == tabID }
    if tabs.isEmpty {
      addNewTab()
    } else if selectedTabID == tabID {
      selectedTabID = tabs.first?.id ?? ""
    }
  }

  // MARK: - Animations
  private func animateIn() {
    toolbarOffset = 100
    toolbarOpacity = 0

    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
      toolbarOffset = 0
      toolbarOpacity = 1
    }
  }
}

// MARK: - Preview Provider
struct BottomToolbarView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      Spacer()
      BottomToolbarView(
        tabs: .constant([
          TabInfo(url: URL(string: "https://apple.com"), title: "Apple"),
          TabInfo(url: URL(string: "https://google.com"), title: "Google"),
          TabInfo(url: URL(string: "https://github.com"), title: "GitHub")
        ]),
        selectedTabID: .constant("1")
      )
    }
    .background(Color.gray.opacity(0.1))
    .ignoresSafeArea()
  }
}