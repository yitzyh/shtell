import SwiftUI
import Combine

// MARK: - Transition Direction
enum SlideDirection {
    case fromTop    // Pull down from top
    case fromBottom // Pull up from bottom
    case none
}

// MARK: - Transition State
enum TransitionState {
    case idle
    case animating
    case completed
}

// MARK: - Slide Transition Manager
@MainActor
class SlideTransitionManager: ObservableObject {
    @Published var isTransitioning = false
    @Published var transitionDirection: SlideDirection = .none
    @Published var transitionState: TransitionState = .idle

    // Animation parameters (TikTok-style)
    let slideAnimationDuration: Double = 0.25 // 250ms sweet spot
    let springDamping: Double = 0.85 // Slight bounce for natural feel
    let springResponse: Double = 0.25

    private var transitionCompletionHandler: (() -> Void)?

    // MARK: - Start Transition
    func startTransition(direction: SlideDirection, onComplete: @escaping () -> Void) {
        guard !isTransitioning else {
            print("⚠️ SlideTransitionManager: Transition already in progress, ignoring")
            return
        }

        transitionDirection = direction
        transitionCompletionHandler = onComplete
        transitionState = .animating

        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            isTransitioning = true
        }

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("🎬 SlideTransitionManager: Starting \(direction) transition")
        }
        #endif
    }

    // MARK: - Complete Transition
    func completeTransition() {
        guard isTransitioning else { return }

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("✅ SlideTransitionManager: Completing transition")
        }
        #endif

        transitionState = .completed

        // Brief delay to allow animation to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.15)) {
                self.isTransitioning = false
                self.transitionDirection = .none
                self.transitionState = .idle
            }

            // Call completion handler
            self.transitionCompletionHandler?()
            self.transitionCompletionHandler = nil
        }
    }

    // MARK: - Cancel Transition
    func cancelTransition() {
        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("❌ SlideTransitionManager: Canceling transition")
        }
        #endif

        isTransitioning = false
        transitionDirection = .none
        transitionState = .idle
        transitionCompletionHandler = nil
    }

    // MARK: - Offset Calculation
    func offsetForDirection(_ direction: SlideDirection, screenHeight: CGFloat) -> CGFloat {
        switch direction {
        case .fromTop:
            return -screenHeight // Slide in from above
        case .fromBottom:
            return screenHeight  // Slide in from below
        case .none:
            return 0
        }
    }

    // MARK: - Current Offset for Transitioning View
    func currentTransitionOffset(screenHeight: CGFloat) -> CGFloat {
        guard isTransitioning else { return 0 }

        switch transitionState {
        case .idle:
            return offsetForDirection(transitionDirection, screenHeight: screenHeight)
        case .animating:
            return 0 // Slides to center
        case .completed:
            return -offsetForDirection(transitionDirection, screenHeight: screenHeight) // Slides out opposite direction
        }
    }
}
