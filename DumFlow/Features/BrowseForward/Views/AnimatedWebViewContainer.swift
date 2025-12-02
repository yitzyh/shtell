import SwiftUI
import WebKit

// MARK: - Animated WebView Container for BrowseForward Transitions
struct AnimatedWebViewContainer: View {
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @Binding var scrollProgress: CGFloat

    var onQuoteText: ((String, String, Int) -> Void)?
    var onCommentTap: ((String) -> Void)?

    @StateObject private var transitionManager = SlideTransitionManager()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Primary WebView - always present
                WebView(
                    scrollProgress: $scrollProgress,
                    onQuoteText: onQuoteText,
                    onCommentTap: onCommentTap
                )
                .environmentObject(webBrowser)
                .environmentObject(browseForwardViewModel)
                .environmentObject(webPageViewModel)
                .zIndex(transitionManager.isTransitioning ? 0 : 1)
                .offset(y: transitionManager.isTransitioning ? slideOutOffset() : 0)
                .opacity(transitionManager.isTransitioning ? 0.7 : 1.0)
                .animation(.spring(response: transitionManager.springResponse, dampingFraction: transitionManager.springDamping), value: transitionManager.isTransitioning)

                // Transitioning content indicator
                if transitionManager.isTransitioning {
                    TransitioningContentView(
                        direction: transitionManager.transitionDirection,
                        transitionState: transitionManager.transitionState,
                        screenHeight: geometry.size.height
                    )
                    .zIndex(2)
                    .animation(.spring(response: transitionManager.springResponse, dampingFraction: transitionManager.springDamping), value: transitionManager.transitionState)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowseForwardInstantTransition"))) { notification in
            handleTransitionNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowseForwardBottomPull"))) { notification in
            handleTransitionNotification(notification)
        }
    }

    private func slideOutOffset() -> CGFloat {
        switch transitionManager.transitionDirection {
        case .fromTop:
            return 50 // Slide down slightly
        case .fromBottom:
            return -50 // Slide up slightly
        case .none:
            return 0
        }
    }

    private func handleTransitionNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let directionString = userInfo["direction"] as? String else { return }

        let direction: SlideDirection = directionString == "bottom" ? .fromBottom : .fromTop

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("🎬 AnimatedWebViewContainer: Starting \(direction) transition")
        }
        #endif

        transitionManager.startTransition(direction: direction) {
            // Transition completed - reset state
            #if DEBUG
            if verboseLogging {
                print("✅ AnimatedWebViewContainer: Transition completed")
            }
            #endif
        }

        // Auto-complete after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionManager.slideAnimationDuration) {
            transitionManager.completeTransition()
        }
    }
}

// MARK: - Transitioning Content View
struct TransitioningContentView: View {
    let direction: SlideDirection
    let transitionState: TransitionState
    let screenHeight: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .overlay(
                VStack(spacing: 16) {
                    Spacer()

                    // Visual feedback during transition
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(width: 200, height: 120)
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

                        VStack(spacing: 12) {
                            // Direction arrow
                            Image(systemName: direction == .fromTop ? "arrow.down" : "arrow.up")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.orange)

                            // Status text
                            Text(transitionState == .animating ? "Loading..." : "Ready")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            // Progress indicator
                            if transitionState == .animating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            }
                        }
                    }

                    Spacer()
                }
            )
            .offset(y: currentOffset())
            .opacity(transitionState == .idle ? 0 : 1)
    }

    private func currentOffset() -> CGFloat {
        switch transitionState {
        case .idle:
            return direction == .fromTop ? -screenHeight : screenHeight
        case .animating:
            return 0 // Slide to center
        case .completed:
            return direction == .fromTop ? screenHeight : -screenHeight // Slide out opposite
        }
    }
}

#Preview {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    let browseForwardViewModel = BrowseForwardViewModel()

    // Setup connections
    webBrowser.webPageViewModel = webPageViewModel
    webBrowser.browseForwardViewModel = browseForwardViewModel

    return AnimatedWebViewContainer(scrollProgress: .constant(0.0))
        .environmentObject(authViewModel)
        .environmentObject(webBrowser)
        .environmentObject(webPageViewModel)
        .environmentObject(browseForwardViewModel)
}
