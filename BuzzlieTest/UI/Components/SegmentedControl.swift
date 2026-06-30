import SwiftUI

/// iOS-style segmented control: a rounded pill glides under the selected segment (critically
/// damped, no overshoot) while fixed labels sit on top. Track is always the outline gray.
struct SegmentedControl<T: Hashable>: View {
    let options: [T]
    let selected: T
    let label: (T) -> String
    let onSelect: (T) -> Void
    var enabled: Bool = true

    private var selIndex: Int { max(options.firstIndex(of: selected) ?? 0, 0) }

    private func textColor(_ isSel: Bool) -> Color {
        if !enabled { return BzColor.onSurfaceVariant.opacity(0.5) }
        return isSel ? BzColor.onSurface : BzColor.onSurfaceVariant
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(BzColor.outline)
            GeometryReader { geo in
                let segWidth = geo.size.width / CGFloat(max(options.count, 1))
                ZStack(alignment: .leading) {
                    if enabled {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(BzColor.segPill)
                            .shadow(color: .black.opacity(0.16), radius: 1.5, y: 1)
                            .frame(width: segWidth)
                            .offset(x: segWidth * CGFloat(selIndex))
                            .animation(.spring(response: 0.32, dampingFraction: 1.0), value: selIndex)
                    }
                    HStack(spacing: 0) {
                        ForEach(options, id: \.self) { option in
                            let isSel = option == selected
                            Text(label(option))
                                .font(.system(size: 13, weight: isSel ? .semibold : .medium))
                                .foregroundStyle(textColor(isSel))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { if enabled { onSelect(option) } }
                                .animation(.easeInOut(duration: 0.2), value: isSel)
                        }
                    }
                }
                .padding(3)
            }
        }
        .frame(height: 40)
    }
}
