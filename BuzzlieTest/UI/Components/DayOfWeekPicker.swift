import SwiftUI

/// Alarm-style day picker: 7 round pills (L M M J V S D) toggling the bits of a mask
/// (bit0=Monday … bit6=Sunday). An active pill = selected day.
struct DayOfWeekPicker: View {
    let mask: Int
    let onChange: (Int) -> Void

    private let letters = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(letters.enumerated()), id: \.offset) { i, letter in
                let selected = mask & (1 << i) != 0
                Text(letter)
                    .font(.system(size: 16, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? BzColor.onPrimary : BzColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(selected ? BzColor.primary : BzColor.surfaceVariant)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .onTapGesture { onChange(mask ^ (1 << i)) }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
