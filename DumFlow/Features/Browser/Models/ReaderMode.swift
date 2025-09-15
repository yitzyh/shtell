import Foundation
import SwiftUI

// MARK: - Reader Mode Settings
class ReaderModeSettings: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var backgroundColor: ReaderBackgroundColor = .white
    @Published var textColor: ReaderTextColor = .black
    @Published var fontSize: ReaderFontSize = .medium
    @Published var fontFamily: ReaderFontFamily = .system
    @Published var lineHeight: ReaderLineHeight = .normal
    @Published var contentWidth: ReaderContentWidth = .normal
    
    // Performance optimization - cache processed content
    @Published var cachedContent: String?
    @Published var isProcessing: Bool = false
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        backgroundColor = ReaderBackgroundColor(rawValue: UserDefaults.standard.string(forKey: "ReaderBackgroundColor") ?? "white") ?? .white
        textColor = ReaderTextColor(rawValue: UserDefaults.standard.string(forKey: "ReaderTextColor") ?? "black") ?? .black
        fontSize = ReaderFontSize(rawValue: UserDefaults.standard.string(forKey: "ReaderFontSize") ?? "medium") ?? .medium
        fontFamily = ReaderFontFamily(rawValue: UserDefaults.standard.string(forKey: "ReaderFontFamily") ?? "system") ?? .system
        lineHeight = ReaderLineHeight(rawValue: UserDefaults.standard.string(forKey: "ReaderLineHeight") ?? "normal") ?? .normal
        contentWidth = ReaderContentWidth(rawValue: UserDefaults.standard.string(forKey: "ReaderContentWidth") ?? "normal") ?? .normal
    }
    
    func saveSettings() {
        UserDefaults.standard.set(backgroundColor.rawValue, forKey: "ReaderBackgroundColor")
        UserDefaults.standard.set(textColor.rawValue, forKey: "ReaderTextColor")
        UserDefaults.standard.set(fontSize.rawValue, forKey: "ReaderFontSize")
        UserDefaults.standard.set(fontFamily.rawValue, forKey: "ReaderFontFamily")
        UserDefaults.standard.set(lineHeight.rawValue, forKey: "ReaderLineHeight")
        UserDefaults.standard.set(contentWidth.rawValue, forKey: "ReaderContentWidth")
    }
    
    func resetToDefaults() {
        backgroundColor = .white
        textColor = .black
        fontSize = .medium
        fontFamily = .system
        lineHeight = .normal
        contentWidth = .normal
        saveSettings()
    }
}

// MARK: - Reader Mode Enums
enum ReaderBackgroundColor: String, CaseIterable {
    case white = "white"
    case cream = "cream"
    case dark = "dark"
    case black = "black"
    
    var displayName: String {
        switch self {
        case .white: return "White"
        case .cream: return "Cream"
        case .dark: return "Dark"
        case .black: return "Black"
        }
    }
    
    var cssValue: String {
        switch self {
        case .white: return "#ffffff"
        case .cream: return "#f7f5f3"
        case .dark: return "#1c1c1e"
        case .black: return "#000000"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .white: return .white
        case .cream: return Color(red: 0.97, green: 0.96, blue: 0.95)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .black: return .black
        }
    }
}

enum ReaderTextColor: String, CaseIterable {
    case black = "black"
    case darkGray = "darkGray"
    case white = "white"
    case lightGray = "lightGray"
    
    var displayName: String {
        switch self {
        case .black: return "Black"
        case .darkGray: return "Dark Gray"
        case .white: return "White"
        case .lightGray: return "Light Gray"
        }
    }
    
    var cssValue: String {
        switch self {
        case .black: return "#000000"
        case .darkGray: return "#333333"
        case .white: return "#ffffff"
        case .lightGray: return "#cccccc"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .black: return .black
        case .darkGray: return Color(red: 0.2, green: 0.2, blue: 0.2)
        case .white: return .white
        case .lightGray: return Color(red: 0.8, green: 0.8, blue: 0.8)
        }
    }
}

enum ReaderFontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var cssValue: String {
        switch self {
        case .small: return "16px"
        case .medium: return "18px"
        case .large: return "20px"
        case .extraLarge: return "24px"
        }
    }
}

enum ReaderFontFamily: String, CaseIterable {
    case system = "system"
    case serif = "serif"
    case sansSerif = "sansSerif"
    case monospace = "monospace"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .sansSerif: return "Sans Serif"
        case .monospace: return "Monospace"
        }
    }
    
    var cssValue: String {
        switch self {
        case .system: return "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
        case .serif: return "Georgia, 'Times New Roman', Times, serif"
        case .sansSerif: return "'Helvetica Neue', Helvetica, Arial, sans-serif"
        case .monospace: return "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace"
        }
    }
}

enum ReaderLineHeight: String, CaseIterable {
    case compact = "compact"
    case normal = "normal"
    case relaxed = "relaxed"
    
    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .normal: return "Normal"
        case .relaxed: return "Relaxed"
        }
    }
    
    var cssValue: String {
        switch self {
        case .compact: return "1.4"
        case .normal: return "1.6"
        case .relaxed: return "1.8"
        }
    }
}

enum ReaderContentWidth: String, CaseIterable {
    case narrow = "narrow"
    case normal = "normal"
    case wide = "wide"
    
    var displayName: String {
        switch self {
        case .narrow: return "Narrow"
        case .normal: return "Normal"
        case .wide: return "Wide"
        }
    }
    
    var cssValue: String {
        switch self {
        case .narrow: return "600px"
        case .normal: return "700px"
        case .wide: return "800px"
        }
    }
}