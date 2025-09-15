//
//  DumFlowApp.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 4/28/24.
//

import SwiftData
import SwiftUI
import CloudKit

@main
struct DumFlowApp: App {
    // ✅ Remove persistenceController
    
    @StateObject private var authViewModel: AuthViewModel
    @StateObject var webBrowser = WebBrowser()
    @StateObject var webPageViewModel: WebPageViewModel
    @StateObject var browseForwardViewModel = BrowseForwardViewModel()
    
    init() {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🚀 DumFlowApp init started")
        
        // ✅ Use pure CloudKit setup
        let authStart = CFAbsoluteTimeGetCurrent()
        let auth = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: auth)
        print("🚀 AuthViewModel init took: \(CFAbsoluteTimeGetCurrent() - authStart)s")

        let pageVMStart = CFAbsoluteTimeGetCurrent()
        let pageVM = WebPageViewModel(authViewModel: auth)
        _webPageViewModel = StateObject(wrappedValue: pageVM)
        print("🚀 WebPageViewModel init took: \(CFAbsoluteTimeGetCurrent() - pageVMStart)s")
        
        
        print("🚀 DumFlowApp init completed in: \(CFAbsoluteTimeGetCurrent() - startTime)s")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // ✅ Remove .environment(\.managedObjectContext, ...)
                .environmentObject(authViewModel)
                .environmentObject(webBrowser)
                .environmentObject(webPageViewModel)
                .environmentObject(browseForwardViewModel)
                .onAppear {
                    setupWebBrowserConnections()
                    checkForSharedURL()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    checkForSharedURL()
                }
        }
    }
    
    private func setupWebBrowserConnections() {
        // Connect services to web browser (safe to do before authentication)
        webBrowser.webPageViewModel = webPageViewModel
        webBrowser.browseForwardViewModel = browseForwardViewModel
        
        // Connect webPageViewModel to browseForwardViewModel
        browseForwardViewModel.setWebPageViewModel(webPageViewModel)
    }
    
    
    private func checkForSharedURL() {
        // Try file-based approach first
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.yitzy.DumFlow") {
            let fileURL = containerURL.appendingPathComponent("sharedURL.txt")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let components = content.components(separatedBy: "|")
                    
                    if components.count == 2,
                       let timestamp = Double(components[1]) {
                        
                        let sharedURL = components[0]
                        let sharedDate = Date(timeIntervalSince1970: timestamp)
                        let tenMinutesAgo = Date().addingTimeInterval(-600)
                        
                        if sharedDate > tenMinutesAgo {
                            // 🔥 FIXED: Dismiss both sheets AND reset navigation
                            dismissAllViewsAndNavigateToRoot()
                            
                            // Navigate to the shared URL
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                webBrowser.urlString = sharedURL
                                webBrowser.isUserInitiatedNavigation = true
                            }
                            
                            // Delete the file
                            try? FileManager.default.removeItem(at: fileURL)
                            return
                        } else {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                    }
                } catch {
                    // Silently handle file reading errors
                }
            }
        }
        
        // Fallback: Check standard UserDefaults
        let defaults = UserDefaults.standard
        
        if let sharedURL = defaults.string(forKey: "SharedURL"),
           let sharedDate = defaults.object(forKey: "SharedURLDate") as? Date {
            
            let tenMinutesAgo = Date().addingTimeInterval(-600)
            
            if sharedDate > tenMinutesAgo {
                // 🔥 FIXED: Dismiss both sheets AND reset navigation
                dismissAllViewsAndNavigateToRoot()
                
                // Navigate to the shared URL
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    webBrowser.urlString = sharedURL
                    webBrowser.isUserInitiatedNavigation = true
                }
                // Clear the shared URL
                defaults.removeObject(forKey: "SharedURL")
                defaults.removeObject(forKey: "SharedURLDate")
                defaults.synchronize()
            } else {
                defaults.removeObject(forKey: "SharedURL")
                defaults.removeObject(forKey: "SharedURLDate")
            }
        }
    }

    private func dismissAllViewsAndNavigateToRoot() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }
        
        // 1. Dismiss any sheets
        rootViewController.dismiss(animated: false)
        
        // 2. Post notification to reset navigation (much more reliable)
        NotificationCenter.default.post(name: NSNotification.Name("ResetToRoot"), object: nil)
    }
}
