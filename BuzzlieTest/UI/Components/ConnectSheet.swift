import SwiftUI
import CoreBluetooth

/// Connect sheet content. On iOS CoreBluetooth requests authorization implicitly on first use,
/// so opening this sheet (which starts a scan) triggers the system Bluetooth prompt — mirroring
/// the Android "permission only when connecting" flow. Shows a spinner while scanning, or a
/// guidance button if Bluetooth is unauthorized / powered off.
struct ConnectSheet: View {
    @ObservedObject var vm: BuzzlieViewModel

    private var scanningLabel: String {
        switch vm.connState {
        case .connecting, .connected: return "Connexion au bracelet…"
        default: return "Recherche du bracelet…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connecter un bracelet").font(BzFont.titleLarge).foregroundStyle(BzColor.onSurface)

            switch vm.centralState {
            case .unauthorized:
                Text("Le Bluetooth n'est pas autorisé pour BUZZLIE.")
                    .font(BzFont.bodyMedium).foregroundStyle(BzColor.onSurfaceVariant)
                settingsButton("Autoriser dans les Réglages")
            case .poweredOff:
                Text("Le Bluetooth est désactivé.")
                    .font(BzFont.bodyMedium).foregroundStyle(BzColor.onSurfaceVariant)
                settingsButton("Activer le Bluetooth")
            default:
                HStack(spacing: 14) {
                    ProgressView().padding(2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scanningLabel).font(BzFont.bodyLarge).foregroundStyle(BzColor.onSurface)
                        Text("Appui 3 s sur le bouton du bracelet.")
                            .font(BzFont.bodySmall).foregroundStyle(BzColor.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .padding(.top, 20)
        .onAppear { vm.startScan() }
        .onDisappear { vm.stopScan() }
        .onChange(of: vm.centralState) { _, newValue in
            if newValue == .poweredOn { vm.startScan() }
        }
    }

    private func settingsButton(_ title: String) -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text(title).font(BzFont.labelLarge).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(BzColor.primary)
    }
}
