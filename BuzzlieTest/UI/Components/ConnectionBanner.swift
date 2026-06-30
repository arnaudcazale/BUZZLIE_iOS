import SwiftUI

/// Tappable connection status banner: a colored status dot + state label, on a surface card.
/// Tappable in every state except mid-connection (connect when down, disconnect when up).
struct ConnectionBanner: View {
    let conn: ConnState
    var onConnect: () -> Void
    var onDisconnect: () -> Void = {}

    private var connected: Bool { conn == .ready || conn == .connected }

    private var dot: Color {
        switch conn {
        case .ready, .connected: return BzColor.connected
        case .connecting: return BzColor.connecting
        case .failed: return BzColor.failed
        case .disconnected: return BzColor.disconnected
        }
    }

    private var label: String {
        switch conn {
        case .ready, .connected: return "Bracelet connecté — toucher pour déconnecter"
        case .connecting: return "Connexion…"
        case .failed: return "Échec de connexion — toucher pour réessayer"
        case .disconnected: return "Bracelet déconnecté — toucher pour connecter"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(dot).frame(width: 10, height: 10)
            Text(label).font(BzFont.bodyMedium).foregroundStyle(BzColor.onSurface)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BzColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: BzRadius.medium, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard conn != .connecting else { return }
            if connected { onDisconnect() } else { onConnect() }
        }
    }
}
