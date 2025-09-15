import Foundation

struct FeatureFlags {
    static let shared = FeatureFlags()
    
    private init() {}
    
    // Firebase feature flag - disabled by default for safety
    var useFirebase: Bool {
        UserDefaults.standard.bool(forKey: "USE_FIREBASE")
    }
    
    // Enable Firebase for testing (only you can enable this)
    func enableFirebase() {
        UserDefaults.standard.set(true, forKey: "USE_FIREBASE")
    }
    
    func disableFirebase() {
        UserDefaults.standard.set(false, forKey: "USE_FIREBASE")
    }
    
    // Debug info
    var debugInfo: String {
        """
        Feature Flags Status:
        - Firebase: \(useFirebase ? "ENABLED" : "DISABLED (CloudKit active)")
        """
    }
}