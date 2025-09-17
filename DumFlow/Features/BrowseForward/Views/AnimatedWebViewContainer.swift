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

    @State private var isTransitioning = false
    @State private var transitionDirection: TransitionDirection = .none

    enum TransitionDirection {
        case none
        case slideFromTop
        case slideFromRight
    }

    var body: some View {
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
            .zIndex(isTransitioning && transitionDirection == .slideFromTop ? 0 : 1)
            .offset(y: isTransitioning && transitionDirection == .slideFromTop ? 100 : 0)
            .opacity(isTransitioning && transitionDirection == .slideFromTop ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isTransitioning)

            // Transitioning WebView - for slide animations
            if isTransitioning {
                TransitioningWebView(
                    direction: transitionDirection,
                    onTransitionComplete: {
                        completeTransition()
                    }
                )
                .environmentObject(webBrowser)
                .environmentObject(browseForwardViewModel)
                .environmentObject(webPageViewModel)
                .zIndex(2)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BrowseForwardInstantTransition"))) { notification in
            if let userInfo = notification.userInfo,
               let direction = userInfo["direction"] as? String {
                startTransition(direction: direction == "top" ? .slideFromTop : .slideFromRight)
            }
        }
    }

    private func startTransition(direction: TransitionDirection) {
        guard !isTransitioning else { return }

        transitionDirection = direction
        withAnimation(.easeInOut(duration: 0.2)) {
            isTransitioning = true
        }
    }

    private func completeTransition() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isTransitioning = false
            transitionDirection = .none
        }
    }
}

// MARK: - Transitioning WebView Component
struct TransitioningWebView: View {
    let direction: AnimatedWebViewContainer.TransitionDirection
    let onTransitionComplete: () -> Void

    @State private var animationOffset: CGFloat = -UIScreen.main.bounds.height
    @State private var animationOpacity: Double = 0.0

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                // This would be a simplified representation
                // In a real implementation, you might use a preloaded WebView
                VStack {
                    Spacer()

                    // Placeholder content during transition
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                Text("Loading next article...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                        )
                        .padding(.horizontal, 40)

                    Spacer()
                }
            )
            .offset(y: animationOffset)
            .opacity(animationOpacity)
            .onAppear {
                performSlideAnimation()
            }
    }

    private func performSlideAnimation() {
        // Slide in from top
        withAnimation(.easeOut(duration: 0.2)) {
            animationOffset = 0
            animationOpacity = 1.0
        }

        // Hold briefly, then complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.1)) {
                animationOffset = UIScreen.main.bounds.height
                animationOpacity = 0.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onTransitionComplete()
            }
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