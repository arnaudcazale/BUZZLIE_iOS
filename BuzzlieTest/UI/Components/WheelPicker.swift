import SwiftUI

/// iOS wheel column over an integer range, rendered with the native UIKit wheel (the genuine
/// iOS wheel feel: snap, momentum, haptics). `pad`/`format` mirror the Android labels.
private struct WheelColumn: View {
    let range: ClosedRange<Int>
    let value: Int
    let format: (Int) -> String
    let onChange: (Int) -> Void

    var body: some View {
        Picker("", selection: Binding(get: { value }, set: { onChange($0) })) {
            ForEach(Array(range), id: \.self) { v in
                Text(format(v)).font(BzFont.titleLarge).tag(v)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/// Total height = 5 visible rows × 40pt = 200pt (matches the Android hand-rolled wheel).
private let wheelHeight: CGFloat = 200

/// Hours (0..23, plain) + minutes (0..59, zero-padded) for a relative delay.
struct DurationPicker: View {
    let hours: Int
    let minutes: Int
    let onChange: (Int, Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            WheelColumn(range: 0...23, value: hours, format: { "\($0)" }) { onChange($0, minutes) }
            Text("h").font(BzFont.titleMedium).padding(.horizontal, 4)
            WheelColumn(range: 0...59, value: minutes, format: { String(format: "%02d", $0) }) { onChange(hours, $0) }
            Text("min").font(BzFont.titleMedium).padding(.leading, 4)
        }
        .frame(height: wheelHeight)
    }
}

/// Hours (0..23, zero-padded) + minutes (0..59, zero-padded) for an absolute time.
struct WheelTimePicker: View {
    let hour: Int
    let minute: Int
    let onChange: (Int, Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            WheelColumn(range: 0...23, value: hour, format: { String(format: "%02d", $0) }) { onChange($0, minute) }
            Text("h").font(BzFont.titleMedium).padding(.horizontal, 4)
            WheelColumn(range: 0...59, value: minute, format: { String(format: "%02d", $0) }) { onChange(hour, $0) }
            Text("min").font(BzFont.titleMedium).padding(.leading, 4)
        }
        .frame(height: wheelHeight)
    }
}
