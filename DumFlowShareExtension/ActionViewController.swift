import UIKit

class ActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSLog("🔵 SHARE EXTENSION LOADED")
        
        setupMinimalUI()
        
        // Process immediately without delay
        processSharedContent()
    }
    
    private func setupMinimalUI() {
        view.backgroundColor = UIColor.clear
        
        let statusLabel = UILabel()
        statusLabel.text = "Opening in Shtell..."
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        statusLabel.tag = 100
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            if let statusLabel = self.view.viewWithTag(100) as? UILabel {
                statusLabel.text = message
            }
        }
    }
    
    private func processSharedContent() {
        NSLog("🔵 Processing shared content...")
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments, !attachments.isEmpty else {
            NSLog("🔴 No attachments found")
            updateStatus("No URL found")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.completeRequest()
            }
            return
        }
        
        NSLog("🔵 Found \(attachments.count) attachments")
        
        // Look for URL
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier("public.url") {
                NSLog("🟢 Found URL attachment")
                loadURL(from: attachment)
                return
            }
        }
        
        NSLog("🔴 No URL attachment found")
        updateStatus("No URL found")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.completeRequest()
        }
    }
    
    private func loadURL(from provider: NSItemProvider) {
        NSLog("🔵 Loading URL from provider")
        
        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, error in
            NSLog("🔵 LoadItem completion")
            
            if let error = error {
                NSLog("🔴 Error loading item: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.updateStatus("Error loading URL")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.completeRequest()
                    }
                }
                return
            }
            
            guard let self = self else { return }
            
            var urlString: String?
            
            if let url = data as? URL {
                NSLog("🟢 Got URL: \(url.absoluteString)")
                urlString = url.absoluteString
            } else if let string = data as? String {
                NSLog("🟢 Got String: \(string)")
                urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            guard let finalURL = urlString else {
                NSLog("🔴 Could not extract URL")
                DispatchQueue.main.async {
                    self.updateStatus("Could not extract URL")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.completeRequest()
                    }
                }
                return
            }
            
            NSLog("🟢 Final URL: \(finalURL)")
            DispatchQueue.main.async {
                self.saveURL(finalURL)
            }
        }
    }
    
    private func saveURL(_ urlString: String) {
        NSLog("🟢 Saving URL: \(urlString)")
        
        // Try file-based approach using App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.yitzy.DumFlow") else {
            NSLog("🔴 Failed to get App Group container URL")
            
            // Fallback: Try UserDefaults without App Group
            let defaults = UserDefaults.standard
            defaults.set(urlString, forKey: "SharedURL")
            defaults.set(Date(), forKey: "SharedURLDate")
            defaults.synchronize()
            NSLog("🟡 URL saved to standard UserDefaults as fallback")
            
            launchMainApp()
            return
        }
        
        // Save to shared file
        let fileURL = containerURL.appendingPathComponent("sharedURL.txt")
        let data = "\(urlString)|\(Date().timeIntervalSince1970)".data(using: .utf8)
        
        do {
            try data?.write(to: fileURL)
            NSLog("🟢 URL saved to App Group file: \(fileURL.path)")
        } catch {
            NSLog("🔴 Failed to save to App Group file: \(error)")
            
            // Fallback to UserDefaults
            let defaults = UserDefaults.standard
            defaults.set(urlString, forKey: "SharedURL")
            defaults.set(Date(), forKey: "SharedURLDate")
            defaults.synchronize()
            NSLog("🟡 URL saved to standard UserDefaults as fallback")
        }
        
        launchMainApp()
    }
    
    private func launchMainApp() {
        NSLog("🟢 Attempting to launch main app...")
        
        updateStatus("Launching Shtell...")
        
        // First test if we can open the URL scheme
        guard let url = URL(string: "dumflow://") else {
            NSLog("🔴 Failed to create URL scheme")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.completeRequest()
            }
            return
        }
        
        // Use extension context to open the main app
        extensionContext?.open(url) { success in
            NSLog("🟢 App launch success: \(success)")
            if success {
                // App launched successfully - wait a moment then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.completeRequest()
                }
            } else {
                // App launch failed - try alternative method
                NSLog("🔴 Extension context open failed, trying alternative...")
                self.tryAlternativeLaunch()
            }
        }
    }
    
    private func tryAlternativeLaunch() {
        // Alternative: Use UIApplication if available
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                if let url = URL(string: "dumflow://") {
                    application.open(url, options: [:]) { success in
                        NSLog("🟢 UIApplication launch success: \(success)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.completeRequest()
                        }
                    }
                    return
                }
            }
            responder = responder?.next
        }
        
        // If all else fails, just complete after a delay
        NSLog("🔴 All launch methods failed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.completeRequest()
        }
    }
    
    private func completeRequest() {
        NSLog("🔵 Completing request")
        extensionContext?.completeRequest(returningItems: [])
    }
}
