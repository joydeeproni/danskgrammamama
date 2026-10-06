import SwiftUI

/// The "Stak" look: paper cards on a plain table, one red accent, no italics anywhere.
/// Every colour has a light and a dark value.
enum Theme {
    static let table = Color(light: 0xFFFFFF, dark: 0x000000)
    static let paper = Color(light: 0xFCFCFA, dark: 0x1C1C1E)
    /// Raised paper on a card: options, hack boxes, inner cards.
    static let paperTint = Color(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let chip = Color(light: 0x1B211F, dark: 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.08)
    /// Sheets lying under a card alternate between two shades, like a real pile.
    static let sheet = Color(light: 0xF7F7F4, dark: 0x3A3A3C)
    static let sheetAlt = Color(light: 0xF0F0EC, dark: 0x303033)
    /// The dark line along the bottom of every sheet in a pile.
    static let sheetLine = Color(light: 0x141A17, dark: 0x000000, lightAlpha: 0.20, darkAlpha: 0.90)
    static let edge = Color(light: 0x141A17, dark: 0xFFFFFF, lightAlpha: 0.11, darkAlpha: 0.09)
    static let rule = Color(light: 0x1B211F, dark: 0xF2F2F7, lightAlpha: 0.12, darkAlpha: 0.12)

    static let ink = Color(light: 0x1B211F, dark: 0xF2F2F7)
    static let pencil = Color(light: 0x5C635F, dark: 0x98989F)

    /// PD3 red. Used for the PD3 stamp, the active gap, wrong answers and the weakest topic.
    static let red = Color(light: 0xC8102E, dark: 0xFF4F5E)
    static let redText = Color(light: 0xA50D26, dark: 0xFF7A85)
    static let redWash = Color(light: 0xC8102E, dark: 0xFF4F5E, lightAlpha: 0.07, darkAlpha: 0.12)
    static let correct = Color(light: 0x2C5A45, dark: 0x5BC48E)
    static let correctWash = Color(light: 0x2C5A45, dark: 0x5BC48E, lightAlpha: 0.09, darkAlpha: 0.15)

    /// Primary buttons: ink on light paper, near-white on dark.
    static let buttonFill = Color(light: 0x1B211F, dark: 0xF2F2F7)
    static let buttonText = Color(light: 0xFFFFFF, dark: 0x000000)

    static let cardRadius: CGFloat = 20
    static let todayRadius: CGFloat = 18
    static let smallRadius: CGFloat = 13
    static let controlRadius: CGFloat = 14
}

// MARK: - Type

/// The system fonts: SF Pro for the interface, New York (the system serif) for Danish text.
/// Sizes are the design's and scale with Dynamic Type.
extension Font {
    enum UIWeight {
        case regular, medium, semibold, bold, heavy
        var system: UIFont.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            }
        }
    }
    enum SerifWeight {
        case regular, medium, semibold
        var system: UIFont.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            }
        }
    }

    static func ui(_ size: CGFloat, _ weight: UIWeight = .regular, relativeTo style: TextStyle = .body) -> Font {
        scaled(UIFont.systemFont(ofSize: size, weight: weight.system), style)
    }

    static func serif(_ size: CGFloat, _ weight: SerifWeight = .regular, relativeTo style: TextStyle = .body) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight.system)
        let serif = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
        return scaled(serif, style)
    }

    private static func scaled(_ font: UIFont, _ style: TextStyle) -> Font {
        Font(UIFontMetrics(forTextStyle: style.uiKit).scaledFont(for: font))
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

// MARK: - Colour helpers

extension Color {
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
