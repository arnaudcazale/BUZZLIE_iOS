import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

private func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// BUZZLIE palette — teal/vert d'eau medical accent, iOS systemGrouped feel.
/// Theme-adaptive roles use light/dark pairs; semantic colors are fixed iOS-system hexes.
enum BzColor {
    // Brand
    static let primary   = dyn(0x2E9C8E, 0x3FB8A8)   // Teal / TealDark
    static let onPrimary = dyn(0xFFFFFF, 0x000000)
    static let secondary = Color(hex: 0x5B8DEF)        // Blue

    // Surfaces / text
    static let background      = dyn(0xF2F2F7, 0x000000)
    static let surface         = dyn(0xFFFFFF, 0x1C1C1E)
    static let surfaceVariant  = dyn(0xE9E9EF, 0x2C2C2E)
    static let onSurface       = dyn(0x1C1C1E, 0xF2F2F7)
    static let onSurfaceVariant = dyn(0x6E6E73, 0x9A9AA0)
    static let outline         = dyn(0xE2E2E7, 0x3A3A3C)
    static let error           = Color(hex: 0xD7373F)

    // SegmentedControl selected pill (white in light, gray in dark)
    static let segPill = dyn(0xFFFFFF, 0x5C5C5E)

    // Semantic (fixed iOS system palette)
    static let connected   = Color(hex: 0x34C759) // green
    static let connecting  = Color(hex: 0xFF9500) // orange
    static let failed      = Color(hex: 0xFF3B30) // red
    static let disconnected = Color(hex: 0x8E8E93) // gray
    static let batteryGood = Color(hex: 0x34C759)
    static let batteryLow  = Color(hex: 0xFF9500)
    static let batteryCrit = Color(hex: 0xFF3B30)
}
