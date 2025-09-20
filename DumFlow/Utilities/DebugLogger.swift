import Foundation

/// Utility for conditional debug logging to reduce console spam
struct DebugLogger {

    /// Controls whether debug messages are printed
    static let isDebugEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Print debug message only if debug is enabled
    /// - Parameter message: The message to print
    static func log(_ message: String) {
        guard isDebugEnabled else { return }
        print(message)
    }

    /// Print debug message with category only if debug is enabled
    /// - Parameters:
    ///   - category: Debug category (e.g., "BROWSE_FORWARD", "WEBVIEW")
    ///   - message: The message to print
    static func log(category: String, _ message: String) {
        guard isDebugEnabled else { return }
        print("🚀 DEBUG \(category): \(message)")
    }

    /// Print WebView specific debug messages
    /// - Parameter message: The message to print
    static func webView(_ message: String) {
        guard isDebugEnabled else { return }
        print("🔍 DEBUG WebView: \(message)")
    }

    /// Print preferences debug messages
    /// - Parameter message: The message to print
    static func preferences(_ message: String) {
        guard isDebugEnabled else { return }
        print("💾 DEBUG \(message)")
    }

    /// Print BrowseForward debug messages
    /// - Parameter message: The message to print
    static func browseForward(_ message: String) {
        guard isDebugEnabled else { return }
        print("🚀 DEBUG browseForward: \(message)")
    }

    /// Print critical errors that should always be shown
    /// - Parameter message: The error message to print
    static func error(_ message: String) {
        print("🚨 ERROR: \(message)")
    }

    /// Print warnings that should always be shown
    /// - Parameter message: The warning message to print
    static func warning(_ message: String) {
        print("⚠️ WARNING: \(message)")
    }
}