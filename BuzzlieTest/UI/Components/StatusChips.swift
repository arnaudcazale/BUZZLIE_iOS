import SwiftUI

/// Four status flag chips (hardcoded iOS-system colors, independent of theme), wrapping.
struct StatusChips: View {
    let status: StatusFrame

    var body: some View {
        FlowLayout(spacing: 6) {
            Chip("CONFIG_VALID", on: status.configValid, color: Color(hex: 0x34C759))
            Chip("TIME_SYNCED", on: status.timeSynced, color: Color(hex: 0x5B8DEF))
            Chip("LOW_BATT", on: status.lowBatt, color: Color(hex: 0xFF9500))
            Chip("CRIT_BATT", on: status.critBatt, color: Color(hex: 0xFF3B30))
        }
    }

    private func Chip(_ label: String, on: Bool, color: Color) -> some View {
        Text(label)
            .font(BzFont.labelSmall)
            .foregroundStyle(on ? Color.white : BzColor.onSurfaceVariant)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(on ? color : BzColor.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// Minimal flow layout (wraps chips to the next line), iOS 16+.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
