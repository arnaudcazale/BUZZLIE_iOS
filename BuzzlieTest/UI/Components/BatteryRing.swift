import SwiftUI

/// Custom circular battery gauge: a full track arc + a value arc starting at 12 o'clock,
/// round-capped, with the percent centered. Color thresholds: ≤10 crit, ≤25 low, else good.
struct BatteryRing: View {
    let percent: Int?
    var size: CGFloat = 160
    var stroke: CGFloat = 14

    private var p: Int { min(max(percent ?? 0, 0), 100) }

    private var color: Color {
        guard let percent else { return BzColor.onSurfaceVariant }
        let q = min(max(percent, 0), 100)
        if q <= 10 { return BzColor.batteryCrit }
        if q <= 25 { return BzColor.batteryLow }
        return BzColor.batteryGood
    }

    private var fraction: CGFloat { percent == nil ? 0 : CGFloat(p) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(BzColor.surfaceVariant, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .padding(stroke / 2)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(stroke / 2)
                .animation(.easeOut(duration: 0.5), value: fraction)
            Text(percent == nil ? "—" : "\(p) %")
                .font(BzFont.headlineMedium)
                .foregroundStyle(BzColor.onSurface)
        }
        .frame(width: size, height: size)
    }
}
