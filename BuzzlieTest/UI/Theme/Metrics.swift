import CoreGraphics

/// Spacing (Apple rhythm) and corner radii mirroring the Android Spacing/Shape tokens.
enum BzSpacing {
    static let screenH: CGFloat = 20      // horizontal screen padding
    static let sectionGap: CGFloat = 28   // between grouped sections
    static let itemGap: CGFloat = 12      // between cards/rows
    static let cardInset: CGFloat = 16    // inner card padding
    static let rowMinHeight: CGFloat = 52 // inset-grouped row height
    static let iconBox: CGFloat = 32      // leading rounded icon box
    /// Vertical gap actually used between screen children (Android Arrangement.spacedBy(16.dp)).
    static let stack: CGFloat = 16
}

enum BzRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 22   // InsetGroup cards
}
