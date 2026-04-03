import SwiftUI
import WebKit

/// UIViewRepresentable wrapper for a preloaded WKWebView.
/// Optionally attaches a vertical pan gesture recognizer directly to the WKWebView
/// so it fires simultaneously with (and doesn't cancel) WKWebView's own scroll gesture.
struct PreloadedWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: ((CGFloat, CGFloat) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        if onDragChanged != nil || onDragEnded != nil {
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handlePan(_:))
            )
            pan.delegate = context.coordinator
            pan.cancelsTouchesInView = false  // Don't steal taps/links from WKWebView
            webView.addGestureRecognizer(pan)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Push content below the app toolbar (safe area is handled by .automatic)
        let toolbarInset: CGFloat = 44
        if uiView.scrollView.contentInset.top != toolbarInset {
            uiView.scrollView.contentInset.top = toolbarInset
            uiView.scrollView.verticalScrollIndicatorInsets.top = toolbarInset
        }
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDragChanged: onDragChanged, onDragEnded: onDragEnded)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDragChanged: ((CGFloat) -> Void)?
        var onDragEnded: ((CGFloat, CGFloat) -> Void)?

        init(onDragChanged: ((CGFloat) -> Void)?, onDragEnded: ((CGFloat, CGFloat) -> Void)?) {
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)

            // Filter out primarily horizontal gestures using translation,
            // which is reliable (unlike velocity at shouldBegin time).
            if gesture.state == .changed && abs(translation.x) > abs(translation.y) * 1.5 {
                return
            }

            switch gesture.state {
            case .changed:
                onDragChanged?(translation.y)
            case .ended, .cancelled:
                // Only report if gesture was meaningfully vertical
                if abs(translation.y) > abs(translation.x) {
                    onDragEnded?(translation.y, velocity.y)
                }
            default:
                break
            }
        }

        // Run alongside WKWebView's scroll recognizer — don't cancel each other
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}
