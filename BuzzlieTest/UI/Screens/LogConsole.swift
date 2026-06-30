import SwiftUI

struct LogConsole: View {
    let log: [LogEntry]
    let onClear: () -> Void
    var height: CGFloat = 260

    private func color(_ level: LogLevel) -> Color {
        switch level {
        case .op: return Color(hex: 0x9CDCFE)
        case .notify: return Color(hex: 0x7EE787)
        case .error: return Color(hex: 0xFF7B72)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Journal BLE").font(BzFont.titleSmall).foregroundStyle(BzColor.onSurface)
                Spacer()
                Button("Effacer", action: onClear).font(BzFont.bodyMedium).tint(BzColor.primary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(log) { entry in
                        Text("\(Time.clock(entry.timeMs))  \(entry.message)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(color(entry.level))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: height)
            .background(Color(hex: 0x101418))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
