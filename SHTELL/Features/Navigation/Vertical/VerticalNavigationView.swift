//
//  VerticalNavigationView.swift
//  Shtell
//
//  Created for TestFlight 2.1.0 - TikTok-style vertical navigation
//  Example implementation showing how to use the vertical navigation system
//

import SwiftUI
import WebKit

/// Example view demonstrating vertical navigation integration
struct VerticalNavigationView: View {

  @StateObject private var coordinator = VerticalNavigationCoordinator()

  var body: some View {
    ZStack {
      // Main content area
      if let currentPage = coordinator.stateManager.currentPage {
        WebContentView(item: currentPage)
          .offset(y: coordinator.verticalOffset)
      } else {
        placeholderView
      }

      // Debug overlay (remove in production)
      debugOverlay
    }
    .gesture(coordinator.createVerticalDragGesture())
    .onAppear {
      loadInitialContent()
    }
  }

  // MARK: - Placeholder

  private var placeholderView: some View {
    VStack(spacing: 20) {
      Image(systemName: "arrow.up.arrow.down")
        .font(.system(size: 60))
        .foregroundColor(.gray)

      Text("Pull up/down to navigate")
        .font(.headline)
        .foregroundColor(.secondary)

      Text("Swipe with 500pt/s velocity or 50pt distance")
        .font(.caption)
        .foregroundColor(.tertiary)
    }
  }

  // MARK: - Debug Overlay

  private var debugOverlay: some View {
    VStack {
      Spacer()

      VStack(alignment: .leading, spacing: 8) {
        // Queue position
        HStack {
          Text("Position:")
            .fontWeight(.semibold)
          Text("\(coordinator.stateManager.currentIndex + 1) / \(coordinator.stateManager.queueSize)")
        }

        // Progress bar
        HStack {
          Text("Progress:")
            .fontWeight(.semibold)
          ProgressView(value: coordinator.progress)
            .frame(width: 100)
          Text("\(Int(coordinator.progress * 100))%")
        }

        // Gesture state
        HStack {
          Text("Gesture:")
            .fontWeight(.semibold)
          Text(coordinator.gestureHandler.isGestureActive ? "Active" : "Idle")
        }

        // Animation state
        HStack {
          Text("Animation:")
            .fontWeight(.semibold)
          Text(coordinator.animationController.isAnimating ? "Running" : "Idle")
        }

        // Boundaries
        HStack {
          Text("Edges:")
            .fontWeight(.semibold)
          if coordinator.stateManager.isAtTop {
            Text("TOP")
              .foregroundColor(.orange)
          }
          if coordinator.stateManager.isAtBottom {
            Text("BOTTOM")
              .foregroundColor(.orange)
          }
          if !coordinator.stateManager.isAtTop && !coordinator.stateManager.isAtBottom {
            Text("Middle")
              .foregroundColor(.green)
          }
        }

        // Velocity/Distance debug
        if coordinator.gestureHandler.isGestureActive {
          HStack {
            Text("Will trigger:")
              .fontWeight(.semibold)
            Text(coordinator.gestureHandler.willTriggerNavigation ? "YES" : "NO")
              .foregroundColor(coordinator.gestureHandler.willTriggerNavigation ? .green : .red)
          }
        }
      }
      .padding()
      .background(.ultraThinMaterial)
      .cornerRadius(12)
      .padding()
    }
  }

  // MARK: - Content Loading

  private func loadInitialContent() {
    #if DEBUG
    coordinator.debugLoadSampleContent()
    #else
    // Load from API in production
    // coordinator.loadContent(fetchedItems)
    #endif
  }
}

// MARK: - Web Content View

/// Displays webpage content
struct WebContentView: View {
  let item: WebPageItem

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        if let title = item.title {
          Text(title)
            .font(.headline)
            .lineLimit(1)
        }

        if let category = item.category {
          Text(category.uppercased())
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(.ultraThinMaterial)

      // WebView placeholder (integrate actual WKWebView here)
      WebViewPlaceholder(url: item.url)
    }
  }
}

/// Placeholder for WebView (replace with actual WKWebView integration)
struct WebViewPlaceholder: View {
  let url: URL

  var body: some View {
    ZStack {
      Color.gray.opacity(0.1)

      VStack(spacing: 12) {
        Image(systemName: "globe")
          .font(.system(size: 40))
          .foregroundColor(.blue)

        Text(url.absoluteString)
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Text("WKWebView will render here")
          .font(.caption2)
          .foregroundColor(.tertiary)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  VerticalNavigationView()
}
