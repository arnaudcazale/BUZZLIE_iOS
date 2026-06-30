import SwiftUI

struct ReminderCard: View {
    let reminder: ReminderUi
    let now: Int64
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(BzColor.primary.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: "bell.fill").foregroundStyle(BzColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.whenLabel(now))
                    .font(BzFont.titleMedium).foregroundStyle(BzColor.onSurface)
                Text(Self.countdown(reminder.targetEpoch(now), now))
                    .font(BzFont.bodySmall).foregroundStyle(BzColor.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if reminder.repeats {
                Text("Répété")
                    .font(BzFont.labelSmall)
                    .foregroundStyle(BzColor.onSurfaceVariant)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(BzColor.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BzColor.onSurfaceVariant.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    static func countdown(_ target: Int64, _ now: Int64) -> String {
        let s = target - now
        if s <= 0 { return "maintenant" }
        let h = s / 3600
        let m = (s % 3600) / 60
        switch true {
        case h >= 24: return "dans \(h / 24) j \(h % 24) h"
        case h > 0: return "dans \(h) h \(m) min"
        case m > 0: return "dans \(m) min"
        default: return "dans moins d'une minute"
        }
    }
}
