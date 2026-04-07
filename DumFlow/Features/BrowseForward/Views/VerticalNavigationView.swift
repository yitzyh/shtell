//
//  VerticalNavigationView.swift
//  DumFlow
//
//  TikTok-style vertical navigation using PreloadedWebViewManager.
//
//  Key design decisions:
//  - ForEach keyed on WKWebView identity keeps the same UIKit view in place
//    when a WebView moves between prev/current/next slots. This prevents
//    the black-screen flash caused by removeFromSuperview + addSubview.
//  - Gesture is attached directly to the WKWebView with cancelsTouchesInView=false
//    so taps/links still work inside the page.
//

import SwiftUI
import WebKit

struct VerticalNavigationView: View {
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel

    /// When the search overlay is open, suppress pool reinit so WKWebView.load()
    /// doesn't steal UIKit first responder from the search TextField.
    var searchIsFocused: FocusState<Bool>.Binding

    @StateObject private var pool = PreloadedWebViewManager()

    @State private var dragOffset: CGFloat = 0
    @State private var isTransitioning = false
    @State private var pendingCommit: Task<Void, Never>?

    private let distanceThreshold: CGFloat = 80
    private let velocityThreshold: CGFloat = 500

    // MARK: - Slot model

    /// Stable slot: identity is the WKWebView pointer so ForEach never
    /// destroys/recreates the UIView when the same WebView changes slots.
    private struct Slot: Identifiable {
        var id: ObjectIdentifier { ObjectIdentifier(webView) }
        let webView: WKWebView
        let baseOffset: CGFloat   // -H, 0, or +H
        let isCurrent: Bool
    }

    private func makeSlots(screenHeight: CGFloat) -> [Slot] {
        var slots: [Slot] = []
        // Next sits ABOVE (-H): pull down brings it in from the top.
        // Prev sits BELOW (+H): kept for button-driven back navigation.
        if let wv = pool.getNextWebView() {
            slots.append(Slot(webView: wv, baseOffset: -screenHeight, isCurrent: false))
        }
        if let wv = pool.getCurrentWebView() {
            slots.append(Slot(webView: wv, baseOffset: 0, isCurrent: true))
        }
        if let wv = pool.getPrevWebView() {
            slots.append(Slot(webView: wv, baseOffset: screenHeight, isCurrent: false))
        }
        return slots
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(makeSlots(screenHeight: geometry.size.height)) { slot in
                    PreloadedWebViewRepresentable(
                        webView: slot.webView,
                        onDragChanged: slot.isCurrent ? { dy in
                            guard !isTransitioning else { return }
                            let hasNext = browseForwardViewModel.currentItemIndex < browseForwardViewModel.displayedItems.count - 1
                            // Pull DOWN from top → next item. Normal in-page scroll is unaffected
                            // because we only respond when at the very top of the page.
                            if dy > 0 && hasNext && pool.isAtTopOfCurrentPage {
                                dragOffset = dy * 0.35
                            }
                        } : nil,
                        onDragEnded: slot.isCurrent ? { dy, vy in
                            let hasNext = browseForwardViewModel.currentItemIndex < browseForwardViewModel.displayedItems.count - 1
                            if (dy > distanceThreshold || vy > velocityThreshold) && hasNext && pool.isAtTopOfCurrentPage {
                                commitNext(screenHeight: geometry.size.height)
                            } else {
                                snapBack()
                            }
                        } : nil
                    )
                    .ignoresSafeArea()
                    .offset(y: slot.baseOffset + dragOffset)
                    .allowsHitTesting(slot.isCurrent)
                    .zIndex(slot.isCurrent ? 1 : 0)
                }
            }
        }
        .onAppear {
            pool.setDependencies(
                browseForwardViewModel: browseForwardViewModel,
                webBrowser: webBrowser,
                webPageViewModel: webPageViewModel
            )
            pool.initializeWebViews()
        }
        // Forward button / external navigation: if browseForwardViewModel.currentItemIndex
        // is bumped externally, walk the pool to match.
        .onChange(of: browseForwardViewModel.currentItemIndex) { old, new in
            if new < old {
                // Backward always goes through — cancels any pending forward commit
                navigatePoolBackward(steps: old - new)
            } else if new > old {
                guard !isTransitioning else { return }
                navigatePoolForward(steps: new - old)
            }
        }
        // When the API replaces the items array, reset the pool so it loads
        // the new URLs instead of the old hardcoded ones.
        // Skip reinit while search is open: calling webView.load() steals UIKit
        // first responder from the search TextField, killing searchIsFocused.
        .onChange(of: browseForwardViewModel.items) { _, newItems in
            guard !newItems.isEmpty, !isTransitioning, !searchIsFocused.wrappedValue else {
                if searchIsFocused.wrappedValue {
                    print("⏸ VerticalNavigationView: Deferring pool reinit — search overlay is open")
                }
                return
            }
            pool.reinitializeWebViews()
        }
        // Deferred reinit: when search closes, catch up if items changed while it was open.
        .onChange(of: searchIsFocused.wrappedValue) { _, nowFocused in
            guard !nowFocused, !browseForwardViewModel.items.isEmpty, !isTransitioning else { return }
            let poolItemIndex = pool.currentItemIndex
            let vmItemIndex = browseForwardViewModel.currentItemIndex
            if poolItemIndex != vmItemIndex {
                print("🔄 VerticalNavigationView: Search closed, pool out of sync — reiniting")
                pool.reinitializeWebViews()
            }
        }
    }

    // MARK: - Navigation

    private func commitNext(screenHeight: CGFloat) {
        guard !isTransitioning else { return }
        isTransitioning = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            dragOffset = screenHeight
        }
        pendingCommit?.cancel()
        pendingCommit = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            pool.navigateToNext()
            browseForwardViewModel.currentItemIndex = min(
                browseForwardViewModel.currentItemIndex + 1,
                browseForwardViewModel.displayedItems.count - 1
            )
            dragOffset = 0
            isTransitioning = false
        }
    }

    private func commitPrev(screenHeight: CGFloat) {
        guard !isTransitioning else { return }
        isTransitioning = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            dragOffset = screenHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            pool.navigateToPrevious()
            browseForwardViewModel.currentItemIndex = max(
                browseForwardViewModel.currentItemIndex - 1, 0
            )
            dragOffset = 0
            isTransitioning = false
        }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = 0
        }
    }

    /// Called when forward button bumps currentItemIndex externally.
    private func navigatePoolForward(steps: Int) {
        isTransitioning = true
        for _ in 0..<steps {
            // Skip if pool already advanced (e.g. commitNext called navigateToNext directly)
            if pool.currentItemIndex < browseForwardViewModel.currentItemIndex {
                pool.navigateToNext()
            }
        }
        isTransitioning = false
    }

    private func navigatePoolBackward(steps: Int) {
        pendingCommit?.cancel()
        pendingCommit = nil
        dragOffset = 0          // snap back any in-flight animation
        isTransitioning = true
        for _ in 0..<steps { pool.navigateToPrevious() }
        isTransitioning = false
    }
}
