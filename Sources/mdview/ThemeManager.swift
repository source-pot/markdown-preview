import Foundation
import AppKit

enum Theme: String {
    case light
    case dark
    case auto
}

class ThemeManager {
    static let shared = ThemeManager()

    private let themeKey = "theme"

    var currentTheme: Theme {
        get {
            if let value = UserDefaults.standard.string(forKey: themeKey),
               let theme = Theme(rawValue: value) {
                return theme
            }
            return .auto
        }
    }

    func setTheme(_ theme: Theme) {
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    var effectiveTheme: Theme {
        switch currentTheme {
        case .auto:
            let appearance = NSApp.effectiveAppearance
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return .dark
            }
            return .light
        default:
            return currentTheme
        }
    }

    private init() {}
}
