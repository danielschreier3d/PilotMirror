import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Adaptive semantic colors
// These use UIColor(dynamicProvider:) so they automatically return the correct
// variant when .preferredColorScheme() is applied at the root level.
// ─────────────────────────────────────────────────────────────────────────────
extension Color {
    /// Full-screen background  (navy dark / system grouped light)
    static let appBG = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1)
            : UIColor.systemGroupedBackground
    })

    /// Card / section background
    static let appCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.systemBackground
    })

    /// Subtle field / input background
    static let appInputBG = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.systemBackground
    })

    /// Card border / separator
    static let appBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor.separator.withAlphaComponent(0.4)
    })

    /// Primary text  (white dark / label light)
    static let appPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor.white : UIColor.label
    })

    /// Secondary text  (white 60% dark / secondaryLabel light)
    static let appSecondary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.6)
            : UIColor.secondaryLabel
    })

    /// Tertiary text  (white 40% dark / tertiaryLabel light)
    static let appTertiary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor.tertiaryLabel
    })
}
