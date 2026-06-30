import SwiftUI

/// iOS-style horizontal slider for the global alarm vibration duration (seconds). Continuous
/// track, snaps to whole seconds, value shown on the right. Distinct from the wheel pickers.
struct DurationSlider: View {
    let seconds: Int
    let onChange: (Int) -> Void
    let range: ClosedRange<Int>
    var enabled: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Slider(
                value: Binding(
                    get: { Double(min(max(seconds, range.lowerBound), range.upperBound)) },
                    set: { onChange(min(max(Int($0.rounded()), range.lowerBound), range.upperBound)) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
            .tint(BzColor.primary)
            .disabled(!enabled)
            .frame(maxWidth: .infinity)

            Text("\(seconds) s")
                .font(BzFont.titleMedium)
                .foregroundStyle(BzColor.onSurface)
                .multilineTextAlignment(.trailing)
                .frame(width: 44, alignment: .trailing)
                .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
