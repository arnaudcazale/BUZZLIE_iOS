import SwiftUI

/// Type scale mirroring the Android Material 3 theme (SF, sizes in pt).
/// headlineLarge 34/Bold … labelSmall 11/SemiBold.
enum BzFont {
    static let headlineLarge  = Font.system(size: 34, weight: .bold)
    static let headlineMedium = Font.system(size: 28, weight: .bold)
    static let titleLarge     = Font.system(size: 22, weight: .semibold)
    static let titleMedium    = Font.system(size: 17, weight: .semibold)
    static let titleSmall     = Font.system(size: 15, weight: .semibold)
    static let bodyLarge      = Font.system(size: 17, weight: .regular)
    static let bodyMedium     = Font.system(size: 15, weight: .regular)
    static let bodySmall      = Font.system(size: 13, weight: .regular)
    static let labelLarge     = Font.system(size: 16, weight: .medium)
    static let labelMedium    = Font.system(size: 13, weight: .medium)
    static let labelSmall     = Font.system(size: 11, weight: .semibold)
}
