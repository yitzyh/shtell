import Combine
//import CoreData
import Foundation
import SwiftData
import SwiftUI
import UIKit
import WebKit
import CloudKit
import QuartzCore

// MARK: - Extensions
extension Data {
    func toString() -> String {
        return String(data: self, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Simulator Helper Functions
private struct SimulatorHelper {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    static func isLikelySimulatorNetworkIssue(_ error: Error) -> Bool {
        guard isSimulator else { return false }
        
        if let nsError = error as NSError? {
            let simulatorErrorCodes = [-1005, -1009, -1001, -1003, -1004]
            return simulatorErrorCodes.contains(nsError.code)
        }
        
        return false
    }
    
    static var simulatorNetworkFixSuggestion: String {
        """
        Simulator Network Issue Detected:
        
        Try these fixes:
        1. Reset simulator: Device → Erase All Content and Settings
        2. Restart Simulator app completely
        3. Test on physical device
        4. Tap the refresh button below
        """
    }
}

@MainActor
class WebBrowser: ObservableObject{

    @Published var urlString = "shtell://beta"
        {
            didSet {
            }
        }
    @Published var isUserInitiatedNavigation = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var isForwardNavigation = false
    @Published var isReaderMode: Bool = false
    @Published var browseForwardCategory: String? = nil
    @Published var pageBackgroundIsDark: Bool = false

    // SplashScreen properties
    @Published var splashScreenShowCount = 0
    @Published var splashScreenCurrentIndex = 0
    private let splashScreenMaxShows = 3

    weak var wkWebView: WKWebView?
    weak var webPageViewModel: WebPageViewModel?
    weak var browseForwardViewModel: BrowseForwardViewModel?
    var readerModeSettings = ReaderModeSettings()


    // Process pool no longer needed (deprecated iOS 15+)

    // Current page title for tab updates
    private var currentTitle: String?
    
    func goBack()    { wkWebView?.goBack()    }
    func goForward() { wkWebView?.goForward() }
    func reload() { wkWebView?.reload()}

    func jumpToLastForwardPage() {
        // Jump directly to the last page in forward history
        guard let webView = wkWebView, webView.canGoForward else { return }

        // Get the last item in the forward list
        let forwardList = webView.backForwardList.forwardList
        guard let lastForwardItem = forwardList.last else { return }

        // Jump directly to it
        webView.go(to: lastForwardItem)
    }
    
    func scrollToTop() {
        wkWebView?.evaluateJavaScript("window.scrollTo(0, 0);")
    }
    
    // MARK: - Splash Screen Functions
    func shouldShowSplashScreen() -> Bool {
        // Check UserDefaults to see if user has seen splash before
        let hasSeenSplash = UserDefaults.standard.bool(forKey: "hasSeenSplashScreen")
        return !hasSeenSplash
    }

    func markSplashScreenAsSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenSplashScreen")
    }
    
    func getSplashScreenHTML() -> String {
        // Always return the same splash screen with instruction text
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        background: #000000;
                        color: #ff6b35;
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        margin: 0;
                        padding: 0;
                        height: 100vh;
                        width: 100vw;
                        display: flex;
                        flex-direction: column;
                        align-items: center;
                        justify-content: center;
                        text-align: center;
                        overflow-x: hidden;
                        overflow-y: auto;
                        position: relative;
                    }
                    .version {
                        position: absolute;
                        top: 50%;
                        left: 50%;
                        transform: translateX(-50%);
                        font-size: 18px;
                        font-weight: 300;
                        opacity: 0.8;
                        text-transform: lowercase;
                    }
                    .arrows {
                        position: absolute;
                        width: 100%;
                        height: 100%;
                        pointer-events: none;
                    }
                    .arrow-up {
                        position: absolute;
                        top: 20px;
                        right: 50%;
                        transform: translateX(50%);
                        font-size: 40px;
                    }
                    .instruction {
                        position: absolute;
                        top: 80px;
                        left: 50%;
                        transform: translateX(-50%);
                        font-size: 16px;
                        font-weight: 400;
                        opacity: 0.7;
                        text-align: center;
                        max-width: 90vw;
                    }
                    .shtell-horizontal {
                        position: absolute;
                        top: 42%;
                        left: 50%;
                        transform: translate(-50%, -50%);
                        width: 90vw;
                        display: flex;
                        justify-content: space-between;
                        padding: 0;
                        box-sizing: border-box;
                        align-items: center;
                    }
                    .letter {
                        font-size: 12vh;
                        font-weight: 700;
                        line-height: 1;
                        margin: 0;
                        padding: 0;
                        flex: 1;
                        text-align: center;
                    }
                    .shtell-vertical {
                        position: absolute;
                        top: 95%;
                        left: 50%;
                        transform: translateX(-50%);
                        width: 90vw;
                        display: flex;
                        flex-direction: column;
                        align-items: center;
                        gap: 0;
                    }
                    .vertical-letter {
                        font-size: 100vw;
                        font-weight: 700;
                        line-height: 0.8;
                        width: 100vw;
                        text-align: center;
                        margin: 0;
                        padding: 0;
                        letter-spacing: 0;
                    }
                    .arrow-grid {
                        position: absolute;
                        top: 90%;
                        left: 50%;
                        transform: translateX(-50%);
                        width: 90vw;
                        display: grid;
                        grid-template-columns: repeat(10, 1fr);
                        gap: 2px;
                        z-index: -1;
                        color: #ff6b35;
                    }
                    .arrow-grid-cell {
                        font-size: 40px;
                        text-align: center;
                        line-height: 1;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }
                </style>
            </head>
            <body>
                <div class="version">beta 1.0.0</div>
                <div class="arrows">
                    <div class="arrow-up">↑</div>
                    <div class="instruction">Pull down or tap orange button to browse forward</div>
                </div>
                <div class="shtell-horizontal">
                    <div class="letter">S</div>
                    <div class="letter">H</div>
                    <div class="letter">T</div>
                    <div class="letter">E</div>
                    <div class="letter">L</div>
                    <div class="letter">L</div>
                </div>
                <div class="arrow-grid">
            """ + String(repeating: String(repeating: "<div class=\"arrow-grid-cell\">↑</div>", count: 10), count: 70) + """
                </div>
                <div class="shtell-vertical">
                    <div class="vertical-letter">S</div>
                    <div class="vertical-letter">H</div>
                    <div class="vertical-letter">T</div>
                    <div class="vertical-letter">E</div>
                    <div class="vertical-letter">L</div>
                    <div class="vertical-letter">L</div>
                </div>
            </body>
            </html>
            """
    }
    
    func advanceSplashScreen() {
        self.splashScreenShowCount += 1
    }

    func resetSplashScreen() {
        splashScreenShowCount = 0
        splashScreenCurrentIndex = 0
    }

    // MARK: - Home Page Functions
    func getHomePageHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Shtell - The comment section for the internet</title>
            <meta name="description" content="The comment section for the internet. Discover and discuss webpages.">
            <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='0.9em' font-size='90'>🔶</text></svg>">
            <style>
                body {
                    background: #000000;
                    color: #ff6b35;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 0;
                    padding: 0;
                    height: 100vh;
                    width: 100vw;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    text-align: center;
                    overflow: hidden;
                    position: relative;
                }
                .top-arrow-container {
                    position: absolute;
                    top: 80px;
                    left: 50%;
                    transform: translateX(-50%);
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                }
                .top-arrow {
                    font-size: 40px;
                    line-height: 1;
                    margin-bottom: 8px;
                }
                .top-instruction {
                    font-size: 14px;
                    font-weight: 400;
                    opacity: 0.7;
                    white-space: nowrap;
                }
                .logo {
                    font-size: 20vh;
                    font-weight: 700;
                    line-height: 1;
                    margin-bottom: 20px;
                }
                .tagline {
                    font-size: 20px;
                    font-weight: 300;
                    opacity: 0.8;
                    padding: 0 20px;
                }
            </style>
        </head>
        <body>
            <div class="top-arrow-container">
                <div class="top-arrow">↑</div>
                <div class="top-instruction">Pull down to browse forward</div>
            </div>
            <div class="logo">SHTELL</div>
            <div class="tagline">the comment section for the internet</div>
        </body>
        </html>
        """
    }

    // MARK: - Reader Mode Functions
    @MainActor
    func toggleReaderMode() async {
        guard wkWebView != nil else { return }
        
        if isReaderMode {
            await exitReaderMode()
        } else {
            await enterReaderMode()
        }
    }
    
    @MainActor
    private func enterReaderMode() async {
        guard let webView = wkWebView else { return }
        
        readerModeSettings.isProcessing = true
        
        do {
            // Extract content
            let result = try await webView.evaluateJavaScript(ReaderModeService.extractContentScript)
            
            if let resultDict = result as? [String: Any],
               let success = resultDict["success"] as? Bool,
               success {
                
                // Store extracted content
                let storeScript = "\(ReaderModeService.storeExtractedContentScript)(\(try JSONSerialization.data(withJSONObject: resultDict).toString()))"
                try await webView.evaluateJavaScript(storeScript)
                
                // Apply reader mode
                let applyScript = ReaderModeService.applyReaderModeScript(settings: readerModeSettings)
                try await webView.evaluateJavaScript(applyScript)
                
                isReaderMode = true
            }
        } catch {
            print("Failed to enter reader mode: \(error)")
        }
        
        readerModeSettings.isProcessing = false
    }
    
    @MainActor
    private func exitReaderMode() async {
        guard let webView = wkWebView else { return }
        
        do {
            try await webView.evaluateJavaScript(ReaderModeService.exitReaderModeScript)
            isReaderMode = false
        } catch {
            print("Failed to exit reader mode: \(error)")
        }
    }
    
    @MainActor
    func updateReaderModeStyles() async {
        guard isReaderMode, wkWebView != nil else { return }
        
        // Exit and re-enter reader mode with new settings
        await exitReaderMode()
        await enterReaderMode()
    }
    
    
    @MainActor
    func browseForward(category: String? = nil) {
        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("🚀 DEBUG browseForward: === STARTING BROWSE FORWARD ===")
            print("🚀 DEBUG browseForward: Called with category: \(category ?? "nil")")
            print("🚀 DEBUG browseForward: canGoForward: \(canGoForward)")
        }
        #endif

        // If a category is provided, remember it for future browseForward calls
        if let category = category {
            browseForwardCategory = category
        }

        if canGoForward {
            goForward()
        } else {
            guard browseForwardViewModel != nil else {
                #if DEBUG
                print("⚠️ BrowseForward: No ViewModel available, using Wikipedia fallback")
                #endif
                urlString = "https://en.wikipedia.org/wiki/Special:Random"
                isUserInitiatedNavigation = true
                return
            }

            Task { @MainActor in
                await performStandardBrowseForward()
            }
        }
    }


    @MainActor
    private func performStandardBrowseForward() async {
        guard let browseForwardViewModel = browseForwardViewModel else { return }

        #if DEBUG
        let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
        if verboseLogging {
            print("🚀 DEBUG browseForward: Starting standard BrowseForward")
        }
        #endif

        do {
            // Use the new BFP preference system instead of old category system
            let bfQueue = try await browseForwardViewModel.fetchByUserPreferences(limit: 500)

            #if DEBUG
            if verboseLogging {
                print("🚀 DEBUG browseForward: BFP system returned \(bfQueue.count) items")
                if !bfQueue.isEmpty {
                    let firstFewURLs = bfQueue.prefix(3).map { self.cleanURLForLogging($0.url) }
                    print("🚀 DEBUG browseForward: Sample URLs: \(firstFewURLs)")
                }
            }
            #endif

            let nextURL = bfQueue.randomElement()?.url ?? "https://en.wikipedia.org/wiki/Special:Random"

            #if DEBUG
            if verboseLogging {
                print("🚀 DEBUG browseForward: Selected URL: \(self.cleanURLForLogging(nextURL))")
            }
            if nextURL.contains("wikipedia.org") {
                print("⚠️ BrowseForward: Using Wikipedia fallback")
            }
            #endif

            isForwardNavigation = true
            urlString = nextURL
            isUserInitiatedNavigation = true

        } catch {
            #if DEBUG
            print("🚨 BrowseForward: Error fetching content: \(error.localizedDescription)")
            #endif

            // Fallback to Wikipedia Random
            isForwardNavigation = true
            urlString = "https://en.wikipedia.org/wiki/Special:Random"
            isUserInitiatedNavigation = true
        }
    }
    
    // Reset WebView to fix simulator networking issues
    func resetWebView() {
        wkWebView?.stopLoading()
        wkWebView?.removeFromSuperview()
        // Process pool will be recreated on next WebView creation
    }
    
    // MARK: - Background Color Detection
    @MainActor
    func detectPageBackgroundColor() async {
        guard let webView = wkWebView else { return }
        
        let script = """
        (function() {
            function getBackgroundColor(element) {
                let style = window.getComputedStyle(element);
                let bg = style.backgroundColor;
                
                // If transparent, check parent
                if (bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
                    if (element.parentElement) {
                        return getBackgroundColor(element.parentElement);
                        }
                    return 'rgb(255, 255, 255)'; // Default to white
                }
                return bg;
            }
            
            let bodyBg = getBackgroundColor(document.body);
            let htmlBg = getBackgroundColor(document.documentElement);
            
            // Use body color, fallback to html, then white
            let finalBg = bodyBg !== 'rgba(0, 0, 0, 0)' ? bodyBg : htmlBg;
            
            // Parse RGB values
            let match = finalBg.match(/rgb\\((\\d+),\\s*(\\d+),\\s*(\\d+)\\)/);
            if (match) {
                let r = parseInt(match[1]);
                let g = parseInt(match[2]);
                let b = parseInt(match[3]);
                
                // Calculate luminance (perceived brightness)
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
                
                return {
                    color: finalBg,
                    isDark: luminance < 0.5,
                    luminance: luminance
                };
            }
            
            return { color: finalBg, isDark: false, luminance: 1.0 };
        })();
        """
        
        do {
            let result = try await webView.evaluateJavaScript(script)
            if let resultDict = result as? [String: Any],
               let isDark = resultDict["isDark"] as? Bool {
                print("🎨 Background color detection: isDark = \(isDark)")
                pageBackgroundIsDark = isDark
            }
        } catch {
            print("Failed to detect background color: \(error)")
            pageBackgroundIsDark = false // Default to light
        }
    }
    
    // MARK: - Tab Management Functions
    
    
    /// Set the page title (called from WebView coordinator)
    func setCurrentTitle(_ title: String?) {
        self.currentTitle = title
    }
    
    init(urlString: String = "shtell://beta") {
        // Default landing page - will be replaced by BrowseForward after splash
        self.urlString = urlString
    }

    // MARK: - Helper Functions

    /// Clean URL for logging - removes encoded data and long parameters
    private func cleanURLForLogging(_ urlString: String) -> String {
        // Handle data URLs (splash screen, inline HTML)
        if urlString.hasPrefix("data:") {
            if urlString.contains("shtell") {
                return "[SPLASH_SCREEN]"
            }
            return "[DATA_URL]"
        }

        // For regular URLs, just show domain + path (no query params)
        if let url = URL(string: urlString) {
            let hostPath = "\(url.host ?? "unknown")\(url.path)"
            return hostPath.isEmpty ? urlString : hostPath
        }

        return urlString
    }
}

struct WebView: UIViewRepresentable {
    
    @EnvironmentObject var webBrowser: WebBrowser
    @EnvironmentObject var browseForwardViewModel: BrowseForwardViewModel
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @Binding var scrollProgress: CGFloat
    var onQuoteText: ((String, String, Int) -> Void)?
    var onCommentTap: ((String) -> Void)?
    
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        #if DEBUG
        // Suppress WebKit privacy console spam in debug builds
        if #available(iOS 14.0, *) {
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        #endif

        // Add message handler for comment taps
        config.userContentController.add(context.coordinator, name: "commentTap")
        
        // Process pool configuration no longer needed (deprecated iOS 15+)
        
        // Simulator-specific configurations
        if SimulatorHelper.isSimulator {
            // More aggressive caching and network settings for simulator
            config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

            // Suppress privacy-related console spam in simulator
            config.suppressesIncrementalRendering = true
            if #available(iOS 15.0, *) {
                config.preferences.isFraudulentWebsiteWarningEnabled = false
            }
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        webView.allowsBackForwardNavigationGestures = true
        webView.isUserInteractionEnabled = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        
        // Add custom gesture recognizer for forward swipe when nowhere to go
        let forwardSwipeGesture = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleForwardSwipe(_:)))
        forwardSwipeGesture.direction = .left
        forwardSwipeGesture.numberOfTouchesRequired = 1
        webView.addGestureRecognizer(forwardSwipeGesture)
        
        // Setup selection monitoring for quote button
        context.coordinator.setupSelectionMonitoring(for: webView)
        //disable UIKit’s auto-inset adjustments…
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        //once the view hierarchy is up, calculate the inset:
        DispatchQueue.main.async {
            // match whatever you used in ContentView
            let topToolbarHeight: CGFloat = 44
            let bottomToolbarHeight: CGFloat = 50
            
            let topSafe    = webView.window?.safeAreaInsets.top    ?? webView.safeAreaInsets.top
            let bottomSafe = webView.window?.safeAreaInsets.bottom ?? webView.safeAreaInsets.bottom

            let totalTopInset    = topToolbarHeight + topSafe
            let totalBottomInset = bottomToolbarHeight + bottomSafe

            webView.scrollView.contentInset = UIEdgeInsets(
                top:    totalTopInset,
                left:   0,
                bottom: totalBottomInset,
                right:  0
            )
            webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
        }
        
        // Add pull-to-refresh functionality with growing arrow
        let refreshControl = ArrowRefreshControl()
        refreshControl.webBrowser = webBrowser
        refreshControl.addTarget(context.coordinator, action: #selector(context.coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
        webView.scrollView.refreshControl = refreshControl
        
        // Connect ViewModels to WebBrowser
        webBrowser.browseForwardViewModel = browseForwardViewModel
        webBrowser.webPageViewModel = webPageViewModel


        
        // Load splash screen HTML using new system with data URLs for history
        if webBrowser.shouldShowSplashScreen() {
            let splashHTML = webBrowser.getSplashScreenHTML()
            let encodedHTML = splashHTML.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let dataURL = URL(string: "data:text/html;charset=utf-8,\(encodedHTML)")!
            webView.load(URLRequest(url: dataURL))
            webBrowser.advanceSplashScreen()
            webBrowser.markSplashScreenAsSeen()
        } else {
            // Splash already shown - trigger BrowseForward to load first item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webBrowser.browseForward()
            }
        }
        
        context.coordinator.setupWebView(webView)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {

            if webBrowser.isUserInitiatedNavigation {
                if webBrowser.urlString.hasPrefix("shtell://") {
                    // Load splash screen for shtell://beta
                    let splashHTML = webBrowser.getSplashScreenHTML()
                    uiView.loadHTMLString(splashHTML, baseURL: URL(string: webBrowser.urlString))
                } else if let url = URL(string: webBrowser.urlString) {
                    uiView.load(URLRequest(url: url))
                }
                Task { @MainActor in
                    webBrowser.isUserInitiatedNavigation = false
                }

            }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, webBrowser: webBrowser, scrollProgress: $scrollProgress, onQuoteText: onQuoteText, onCommentTap: onCommentTap)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        var parent: WebView
        var webBrowser: WebBrowser
        @Binding var scrollProgress: CGFloat
        var onQuoteText: ((String, String, Int) -> Void)?
        var onCommentTap: ((String) -> Void)?
        
        private var lastContentOffset: CGFloat = 0
        private var quoteButton: UIButton?
        private var urlObservation: NSKeyValueObservation?
        private var canGoBackObserver: NSKeyValueObservation?
        private var canGoForwardObserver: NSKeyValueObservation?
        private var progressObserver: NSKeyValueObservation?
        private weak var webView: WKWebView?
        
        func goBack() { webView?.goBack() }
        func goForward() { webView?.goForward() }
        
        @objc func handleForwardSwipe(_ gesture: UISwipeGestureRecognizer) {
            self.webBrowser.browseForward()
        }
        
        @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
            // Use BrowseForward for social media-style content discovery
            DispatchQueue.main.async {
                #if DEBUG
                let verboseLogging = ProcessInfo.processInfo.environment["BROWSE_FORWARD_VERBOSE"] == "1"
                if verboseLogging {
                    print("🎯 PULL-REFRESH: Starting BrowseForward")
                }
                #endif

                self.webBrowser.browseForward()
                refreshControl.endRefreshing()
            }
        }



        
        func setupSelectionMonitoring(for webView: WKWebView) {
            // Inject JavaScript to monitor text selection
            let script = """
            (function() {
                console.log('🔍 DEBUG JS: Selection monitoring script loaded');
                let lastSelection = '';
                
                function checkSelection() {
                    const selection = window.getSelection();
                    const currentSelection = selection.toString().trim();
                    
                    if (currentSelection !== lastSelection) {
                        lastSelection = currentSelection;
                        console.log('🔍 DEBUG JS: Selection changed to:', currentSelection);
                        
                        if (currentSelection.length > 0) {
                        // Get selection position
                        const range = selection.getRangeAt(0);
                        const rect = range.getBoundingClientRect();
                        
                        window.webkit.messageHandlers.textSelection.postMessage({
                            text: currentSelection,
                            x: rect.left + rect.width / 2,
                            y: rect.bottom,
                            hasSelection: true
                            });
                        } else {
                        window.webkit.messageHandlers.textSelection.postMessage({
                            hasSelection: false
                            });
                        }
                        }
                }
                
                // Monitor selection changes
                document.addEventListener('selectionchange', checkSelection);
                // Remove memory-intensive polling - selectionchange event is sufficient
            })();
            """
            
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(userScript)
            webView.configuration.userContentController.add(self, name: "textSelection")
        }
        
        @objc func quoteSelectedText() {
            print("🔍 DEBUG WebView: quoteSelectedText called")
            guard let webView = webView else { 
                print("🔍 DEBUG WebView: No webView available")
                return 
            }
            extractSelectedTextAndQuote(from: webView)
        }
        
        private func createQuoteButton() -> UIButton {
            var config = UIButton.Configuration.filled()
            config.title = "Quote"
            config.image = UIImage(systemName: "quote.bubble.fill")
            config.baseBackgroundColor = UIColor.systemBlue
            config.baseForegroundColor = .white
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            config.cornerStyle = .fixed
            
            let button = UIButton(configuration: config, primaryAction: UIAction { _ in
                self.quoteButtonTapped()
            })
            
            button.layer.cornerRadius = 20
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            button.layer.shadowOpacity = 0.3
            button.alpha = 0
            return button
        }
        
        @objc func quoteButtonTapped() {
            print("🔍 DEBUG WebView: Quote button tapped!")
            hideQuoteButton()
            quoteSelectedText()
        }
        
        private func showQuoteButton(at position: CGPoint, in webView: WKWebView) {
            hideQuoteButton() // Remove existing button
            
            let button = createQuoteButton()
            quoteButton = button
            webView.addSubview(button)
            
            // Position button below selection
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: webView.leadingAnchor, constant: position.x),
                button.topAnchor.constraint(equalTo: webView.topAnchor, constant: position.y + 10),
                button.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            // Animate in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                button.alpha = 1
                button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    button.transform = .identity
                }
            }
        }
        
        private func hideQuoteButton() {
            quoteButton?.removeFromSuperview()
            quoteButton = nil
        }

        
        init(_ parent: WebView, webBrowser: WebBrowser, scrollProgress: Binding<CGFloat>, onQuoteText: ((String, String, Int) -> Void)?, onCommentTap: ((String) -> Void)?) {
            self.parent = parent
            self.webBrowser = webBrowser
            self._scrollProgress = scrollProgress
            self.onQuoteText = onQuoteText
            self.onCommentTap = onCommentTap
            super.init()
        }
        
        func setupWebView(_ webView: WKWebView) {
            self.webView = webView
            webBrowser.wkWebView = webView


            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, change in
                guard let self = self else { return }
                if let url = change.newValue {
                    DispatchQueue.main.async {
                        let newURLString = url?.absoluteString.stripTrailingSlash() ?? ""
                        // Don't update to data: URLs - keep shtell://beta when loading splash HTML
                        if !newURLString.hasPrefix("data:") {
                            self.webBrowser.urlString = newURLString
                        }
                    }
                }
            }
            // Observe back/forward availability
            canGoBackObserver = webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.webBrowser.canGoBack = wv.canGoBack
                }
            }
            canGoForwardObserver = webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.webBrowser.canGoForward = wv.canGoForward
                }
            }
            
            progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.webBrowser.loadingProgress = wv.estimatedProgress
                }
            }
        }

        deinit {
            urlObservation?.invalidate()
            canGoBackObserver?.invalidate()
            canGoForwardObserver?.invalidate()
            progressObserver?.invalidate()
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.webBrowser.loadingProgress = 0.0
                
                // Track page exit analytics before loading new page
                if let webPageViewModel = self.webBrowser.webPageViewModel {
                    webPageViewModel.browserHistoryService.trackPageExit()
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView: Failed to load - \(error.localizedDescription)")
            
            // Handle simulator-specific networking issues
            if SimulatorHelper.isLikelySimulatorNetworkIssue(error) {
                print("⚠️ Simulator networking issue detected")
                
                // Load fallback content for simulator
                let fallbackHTML = """
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Simulator Network Issue</title>
                </head>
                <body style="font-family: -apple-system; padding: 20px; text-align: center; background: #f5f5f5;">
                    <div style="background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                        <h1 style="color: #ff6b35;">🌐 Network Issue</h1>
                        <p style="color: #666; margin: 20px 0;">Unable to load website in simulator.</p>
                        <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 20px 0;">
                        <strong>Error:</strong> \(error.localizedDescription)
                        </div>
                        <p style="font-size: 14px; color: #888;">
                        \(SimulatorHelper.simulatorNetworkFixSuggestion)
                        </p>
                        <button onclick="location.reload()" 
                            style="background: #ff6b35; color: white; border: none; padding: 12px 24px; border-radius: 6px; font-size: 16px; cursor: pointer;">
                        Try Again
                        </button>
                    </div>
                </body>
                </html>
                """
                
                webView.loadHTMLString(fallbackHTML, baseURL: nil)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView: Navigation failed - \(error.localizedDescription)")
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            print("🚨 WEBKIT CRASH: WebContent process terminated - reloading page")
            webView.reload()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.webBrowser.canGoBack = webView.canGoBack
                self.webBrowser.canGoForward = webView.canGoForward
                self.webBrowser.loadingProgress = 1.0

                // End pull-to-refresh animation if active
                webView.scrollView.refreshControl?.endRefreshing()

                // Reset scroll position for data URLs (splash screen)
                if let url = webView.url?.absoluteString, url.hasPrefix("data:") {
                    webView.scrollView.setContentOffset(.zero, animated: false)
                }

                // Track browser history
                if let url = webView.url?.absoluteString,
                   self.webBrowser.webPageViewModel != nil {

                    // Get page title
                    webView.evaluateJavaScript("document.title") { [weak self] result, error in
                        DispatchQueue.main.async {
                        guard let self = self,
                              let webPageViewModel = self.webBrowser.webPageViewModel else { return }

                        let title = result as? String

                        // Update browser title for tab sync
                        self.webBrowser.setCurrentTitle(title)

                        // Add to history
                        webPageViewModel.browserHistoryService.addToHistory(
                            urlString: url,
                            title: title,
                            referrerURL: self.webBrowser.urlString != url ? self.webBrowser.urlString : nil
                        )
                        }
                        }
                }

                // Detect webpage background color for adaptive UI
                Task {
                    await self.webBrowser.detectPageBackgroundColor()
                }


                // Reset forward navigation flag after loading completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.webBrowser.isForwardNavigation = false
                }

                // Highlight quoted text after page loads
                print("🔍 DEBUG WebView: Page finished loading, triggering highlighting")
                self.highlightQuotedText(in: webView)
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let scrollDelta = currentOffset - lastContentOffset

            // Start minimizing after scrolling 1 screen height OR 20% of content, whichever is smaller
            let webpageLength = max(0, scrollView.contentSize.height - scrollView.frame.height)
            let oneScreenHeight = scrollView.frame.height
            let twentyPercentOfContent = webpageLength * 0.2
            let minimizeThreshold = min(oneScreenHeight, twentyPercentOfContent)

            if scrollDelta > 0 { // Scrolling down
                if currentOffset > minimizeThreshold {
                    // Past threshold - minimize based on user's scroll delta
                    let scrollSensitivity: CGFloat = 120.0 // Higher = slower minimization
                    let newProgress = min(1.0, scrollProgress + (scrollDelta / scrollSensitivity))
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollProgress = newProgress
                        }
                }
            } else if scrollDelta < 0 { // Scrolling up
                // Always expand immediately on upward scroll
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProgress = 0.0
                }
            }
            
            lastContentOffset = currentOffset
            
            // Hide quote button when scrolling
            hideQuoteButton()
            
            // Track scroll depth for analytics - simplified to prevent crashes
            if let webPageViewModel = webBrowser.webPageViewModel {
                let maxScrollOffset = max(0, scrollView.contentSize.height - scrollView.frame.height)
                if maxScrollOffset > 0 {
                    let scrollDepth = min(1.0, max(0.0, currentOffset / maxScrollOffset))
                    webPageViewModel.browserHistoryService.updateScrollDepth(scrollDepth)
                }
            }
        }
        
        
        private func extractSelectedTextAndQuote(from webView: WKWebView) {
            print("🔍 DEBUG WebView: extractSelectedTextAndQuote called")
            let script = """
            (function() {
                var selection = window.getSelection();
                if (selection.rangeCount === 0) return null;
                
                var range = selection.getRangeAt(0);
                var selectedText = range.toString().trim();
                if (selectedText.length === 0) return null;
                
                // Get the container element
                var container = range.commonAncestorContainer;
                if (container.nodeType === Node.TEXT_NODE) {
                    container = container.parentElement;
                }
                
                // Generate CSS selector
                function getSelector(element) {
                    if (element.id) return '#' + element.id;
                    
                    var path = [];
                    while (element && element.nodeType === Node.ELEMENT_NODE) {
                        var selector = element.nodeName.toLowerCase();
                        if (element.className) {
                        selector += '.' + element.className.split(' ').join('.');
                        }
                        path.unshift(selector);
                        element = element.parentElement;
                        }
                    return path.join(' > ');
                }
                
                // Get text offset within the container
                var textOffset = 0;
                var walker = document.createTreeWalker(
                    container,
                    NodeFilter.SHOW_TEXT,
                    null,
                    false
                );
                
                var node;
                while (node = walker.nextNode()) {
                    if (node === range.startContainer) {
                        textOffset += range.startOffset;
                        break;
                        }
                    textOffset += node.textContent.length;
                }
                
                return {
                    text: selectedText,
                    selector: getSelector(container),
                    offset: textOffset
                };
            })();
            """
            
            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🔍 DEBUG WebView: JavaScript error: \(error.localizedDescription)")
                    return
                }
                
                guard let resultDict = result as? [String: Any],
                      let selectedText = resultDict["text"] as? String,
                      let selector = resultDict["selector"] as? String,
                      let offset = resultDict["offset"] as? Int else {
                    print("🔍 DEBUG WebView: Failed to extract quote data - result: \(String(describing: result))")
                    return
                }
                
                print("🔍 DEBUG WebView: Quote extracted successfully: '\(selectedText)'")
                DispatchQueue.main.async {
                    self.onQuoteText?(selectedText, selector, offset)
                }
            }
        }
        
        // MARK: - Quote Highlighting
        func triggerHighlighting() {
            if let webView = self.webView {
                highlightQuotedText(in: webView)
                // Scroll to selected comment's quote if available, with a slight delay to ensure highlighting is done
                if let selectedComment = webBrowser.webPageViewModel?.uiState.selectedComment {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.scrollToQuote(for: selectedComment, in: webView)
                        }
                }
            }
        }
        
        private func highlightQuotedText(in webView: WKWebView) {
            // Get comments with quoted text for current URL
            guard let currentURL = webView.url?.absoluteString,
                  let webPageViewModel = webBrowser.webPageViewModel else { 
                print("🔍 DEBUG highlightQuotedText: No URL or webPageViewModel")
                return 
            }
            
            print("🔍 DEBUG highlightQuotedText: Current URL = \(cleanURLForLogging(currentURL))")
            print("🔍 DEBUG highlightQuotedText: Total comments = \(webPageViewModel.contentState.comments.count)")
            
            let quotedComments = webPageViewModel.contentState.comments.filter { comment in
                comment.urlString == currentURL && comment.quotedText != nil
            }
            
            print("🔍 DEBUG highlightQuotedText: Found \(quotedComments.count) quoted comments")
            
            guard !quotedComments.isEmpty else { 
                print("🔍 DEBUG highlightQuotedText: No quoted comments found")
                return 
            }
            
            // Create JavaScript to highlight all quoted text
            let script = createHighlightScript(for: quotedComments)
            
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Error highlighting quoted text: \(error.localizedDescription)")
                } else {
                    print("Successfully highlighted \(quotedComments.count) quoted texts")
                }
            }
        }
        
        private func createHighlightScript(for comments: [Comment]) -> String {
            var commentsData: [[String: Any]] = []
            
            for comment in comments {
                if let quotedText = comment.quotedText,
                   let selector = comment.quotedTextSelector {
                    commentsData.append([
                        "commentID": comment.commentID,
                        "text": quotedText,
                        "selector": selector,
                        "offset": comment.quotedTextOffset ?? 0
                    ])
                }
            }
            
            guard let commentsJSON = try? JSONSerialization.data(withJSONObject: commentsData, options: []),
                  let commentsJSONString = String(data: commentsJSON, encoding: .utf8) else {
                print("Failed to serialize comments JSON")
                return ""
            }
            
            return """
            (function() {
                const comments = \(commentsJSONString);
                
                // Add CSS styles for highlighting
                const style = document.createElement('style');
                style.textContent = `
                        .dumflow-quote-highlight {
                        background-color: rgba(255, 235, 59, 0.3);
                        border-radius: 3px;
                        cursor: pointer;
                        position: relative;
                        transition: background-color 0.2s ease;
                        }
                        .dumflow-quote-highlight:hover {
                        background-color: rgba(255, 235, 59, 0.5);
                        }
                        .dumflow-quote-highlight::after {
                        content: '💬';
                        position: absolute;
                        right: -20px;
                        top: -5px;
                        font-size: 12px;
                        opacity: 0.7;
                        }
                `;
                document.head.appendChild(style);
                
                // Function to find and highlight text
                function findAndHighlightText(comment) {
                    try {
                        const element = document.querySelector(comment.selector);
                        if (!element) return false;
                        
                        // Find the text within the element
                        const walker = document.createTreeWalker(
                        element,
                        NodeFilter.SHOW_TEXT,
                        null,
                        false
                        );
                        
                        let currentOffset = 0;
                        let node;
                        
                        while (node = walker.nextNode()) {
                        const nodeLength = node.textContent.length;
                        
                        if (currentOffset + nodeLength >= comment.offset) {
                            const startIndex = comment.offset - currentOffset;
                            const endIndex = startIndex + comment.text.length;
                            
                            if (endIndex <= nodeLength) {
                                // Text is within this node
                                const actualText = node.textContent.substring(startIndex, endIndex);
                                
                                if (actualText === comment.text) {
                                    // Create highlight span
                                    const range = document.createRange();
                                    range.setStart(node, startIndex);
                                    range.setEnd(node, endIndex);
                                    
                                    const span = document.createElement('span');
                                    span.className = 'dumflow-quote-highlight';
                                    span.setAttribute('data-comment-id', comment.commentID);
                                    
                                    // Add click handler
                                    span.addEventListener('click', function(e) {
                                        e.preventDefault();
                                        e.stopPropagation();
                                        window.webkit.messageHandlers.commentTap.postMessage({
                                            commentID: comment.commentID
                                            });
                                        });
                                    
                                    range.surroundContents(span);
                                    return true;
                                    }
                                }
                            break;
                            }
                        
                        currentOffset += nodeLength;
                        }
                        
                        return false;
                        } catch (error) {
                        console.error('Error highlighting text:', error);
                        return false;
                        }
                }
                
                // Highlight all comments
                let highlightedCount = 0;
                comments.forEach(comment => {
                    if (findAndHighlightText(comment)) {
                        highlightedCount++;
                        }
                });
                
                return highlightedCount;
            })();
            """
        }
        
        private func scrollToQuote(for comment: Comment, in webView: WKWebView) {
            // Only scroll if this comment has quoted text for the current URL
            guard let currentURL = webView.url?.absoluteString,
                  comment.urlString == currentURL,
                  comment.quotedText != nil,
                  let selector = comment.quotedTextSelector else { 
                print("🔍 DEBUG scrollToQuote: No matching quote for current URL")
                return 
            }
            
            let scrollScript = """
            (function() {
                try {
                    // Find the specific highlighted element for this comment
                    const highlightedElement = document.querySelector('[data-comment-id="\(comment.commentID)"]');
                    
                    if (highlightedElement) {
                        // Scroll to the highlighted element
                        highlightedElement.scrollIntoView({ 
                        behavior: 'smooth', 
                        block: 'center',
                        inline: 'nearest'
                        });
                        
                        // Flash the highlight to draw attention
                        highlightedElement.style.backgroundColor = 'rgba(255, 193, 7, 0.8)';
                        setTimeout(() => {
                        highlightedElement.style.backgroundColor = 'rgba(255, 235, 59, 0.3)';
                        }, 1000);
                        
                        return 'scrolled_to_highlight';
                        } else {
                        // Fallback: try to find and scroll to the text using selector
                        const element = document.querySelector('\(selector)');
                        if (element) {
                        element.scrollIntoView({ 
                            behavior: 'smooth', 
                            block: 'center',
                            inline: 'nearest'
                            });
                        return 'scrolled_to_element';
                        }
                        }
                    
                    return 'not_found';
                } catch (error) {
                    console.error('Error scrolling to quote:', error);
                    return 'error';
                }
            })();
            """
            
            webView.evaluateJavaScript(scrollScript) { result, error in
                if let error = error {
                    print("Error scrolling to quote: \(error.localizedDescription)")
                } else if let result = result as? String {
                    print("✅ Scroll to quote result: \(result)")
                    
                    // Clear the selectedComment after successful navigation
                    DispatchQueue.main.async {
                        self.webBrowser.webPageViewModel?.uiState.selectedComment = nil
                        }
                }
            }
        }
        
        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "commentTap",
               let body = message.body as? [String: Any],
               let commentID = body["commentID"] as? String {
                DispatchQueue.main.async {
                    self.onCommentTap?(commentID)
                }
            }
            else if message.name == "textSelection",
                     let body = message.body as? [String: Any] {
                print("🔍 DEBUG WebView: Received textSelection message: \(body)")
                DispatchQueue.main.async {
                    if let hasSelection = body["hasSelection"] as? Bool, hasSelection,
                       let x = body["x"] as? Double,
                       let y = body["y"] as? Double,
                       let webView = self.webView {
                        
                        print("🔍 DEBUG WebView: Showing quote button at position (\(x), \(y))")
                        let position = CGPoint(x: x, y: y)
                        self.showQuoteButton(at: position, in: webView)
                        } else {
                        print("🔍 DEBUG WebView: Hiding quote button")
                        self.hideQuoteButton()
                        }
                }
            }
        }

        // MARK: - Helper Functions

        /// Clean URL for logging - removes encoded data and long parameters
        private func cleanURLForLogging(_ urlString: String) -> String {
            // Handle data URLs (splash screen, inline HTML)
            if urlString.hasPrefix("data:") {
                if urlString.contains("shtell") {
                    return "[SPLASH_SCREEN]"
                }
                return "[DATA_URL]"
            }

            // For regular URLs, just show domain + path (no query params)
            if let url = URL(string: urlString) {
                let hostPath = "\(url.host ?? "unknown")\(url.path)"
                return hostPath.isEmpty ? urlString : hostPath
            }

            return urlString
        }

    }
}

#Preview("WebView"){
    
    @Previewable @State var scrollProgress: CGFloat = 0.0
    WebView(scrollProgress: $scrollProgress)
        .environmentObject(WebBrowser(urlString: "https://www.cnn.com/"))
}



// MARK: - Custom Arrow Refresh Control

class ArrowRefreshControl: UIRefreshControl {
    weak var webBrowser: WebBrowser?
    private let arrowView = UIImageView()
    private var hasTriggered = false
    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    override init() {
        super.init()
        setupArrowView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupArrowView()
    }
    
    private func setupArrowView() {
        // Hide default spinner
        tintColor = .clear
        
        // Setup arrow
        arrowView.image = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
        arrowView.contentMode = .scaleAspectFit
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrowView)
        
        // Center the arrow
        NSLayoutConstraint.activate([
            arrowView.centerXAnchor.constraint(equalTo: centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 24),
            arrowView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Initial state - hidden but full size
        arrowView.alpha = 0
        arrowView.transform = .identity  // No scaling - keep at full size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateArrow()
    }
    
    private func updateArrow() {
        guard let scrollView = superview as? UIScrollView else {
            print("🎯 PULL ERROR: No scrollView found")
            return
        }
        // Calculate pull distance and progress
        let pullDistance = max(0, -scrollView.contentOffset.y - scrollView.adjustedContentInset.top)
        let progress = min(1.0, pullDistance / 80.0) // 80pts for full size (increased from 60)

        // Update arrow scale with more dramatic growth
        let scale = 0.1 + (progress * 1.1) // Allow slight overgrowth for better feedback
        arrowView.transform = CGAffineTransform(scaleX: scale, y: scale)

        // Enhanced alpha progression for better visibility
        arrowView.alpha = min(1.0, progress * 1.2)


        // Update color and add visual enhancements based on pull progress
        if let webBrowser = webBrowser {
            let baseColor = webBrowser.pageBackgroundIsDark ? UIColor.white : UIColor.black

            // Change to orange when ready to trigger (90% progress)
            if progress >= 0.9 {
                arrowView.tintColor = .systemOrange
                // Add subtle bounce effect when ready
                if arrowView.layer.animation(forKey: "pulse") == nil {
                    let pulse = CABasicAnimation(keyPath: "transform.scale")
                    pulse.fromValue = 1.0
                    pulse.toValue = 1.1
                    pulse.duration = 0.3
                    pulse.autoreverses = true
                    pulse.repeatCount = .infinity
                    arrowView.layer.add(pulse, forKey: "pulse")
                }
            } else {
                arrowView.tintColor = baseColor
                arrowView.layer.removeAnimation(forKey: "pulse")
            }
        }
    }
    
    override func endRefreshing() {
        // Remove any pulse animation
        arrowView.layer.removeAnimation(forKey: "pulse")


        // Animate arrow disappearing with spring effect for satisfying feedback
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, animations: {
            self.arrowView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.arrowView.alpha = 0
            self.arrowView.tintColor = self.webBrowser?.pageBackgroundIsDark == true ? .white : .black
        }) { _ in
            super.endRefreshing()
        }
    }
}

// MARK: - Preview

#Preview {
    let authViewModel = AuthViewModel()
    let webBrowser = WebBrowser(urlString: "https://www.apple.com")
    let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
    
    
    ContentView()
        .environmentObject(authViewModel)
        .environmentObject(webBrowser)
        .environmentObject(webPageViewModel)
}
