import SwiftUI

struct RappelsScreen: View {
    @ObservedObject var vm: BuzzlieViewModel
    let onAddReminder: () -> Void
    let onEditReminder: (String) -> Void
    let onConnect: () -> Void

    @State private var now = Time.nowSeconds()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var reminders: [ReminderUi] { vm.settings.reminders }
    private var maxN: Int { BuzzlieGatt.maxEntries }
    private var full: Bool { reminders.count >= maxN }

    var body: some View {
        ScreenScaffold {
            ScreenHeader("Rappels") {
                Button(action: onAddReminder) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(full ? BzColor.onSurfaceVariant : .white)
                        .frame(width: 36, height: 36)
                        .background(full ? BzColor.surfaceVariant : BzColor.primary)
                        .clipShape(Circle())
                }
                .disabled(full)
            }

            ConnectionBanner(conn: vm.connState, onConnect: onConnect, onDisconnect: { vm.disconnect() })

            if vm.importedFromDevice > 0 {
                Banner(
                    icon: "arrow.down.circle.fill",
                    tint: BzColor.connected,
                    text: vm.importedFromDevice == 1 ? "1 alarme récupérée du bracelet"
                        : "\(vm.importedFromDevice) alarmes récupérées du bracelet",
                    onClose: { vm.dismissImportedBanner() }
                )
            }

            if reminders.isEmpty {
                EmptyState(onAdd: onAddReminder)
            } else {
                syncBanner
                InsetGroup("\(reminders.count)/\(maxN) rappels") {
                    ForEach(Array(reminders.enumerated()), id: \.element.id) { i, r in
                        ReminderCard(reminder: r, now: now, onTap: { onEditReminder(r.id) })
                        if i < reminders.count - 1 { RowDivider() }
                    }
                }
                if full {
                    Text("Bracelet plein : supprimez un rappel pour en ajouter un autre.")
                        .font(BzFont.bodySmall)
                        .foregroundStyle(BzColor.onSurfaceVariant)
                        .padding(.leading, BzSpacing.cardInset)
                }
            }
        }
        .onReceive(ticker) { _ in now = Time.nowSeconds() }
    }

    @ViewBuilder private var syncBanner: some View {
        if vm.connState == .ready && vm.configSynced {
            Banner(icon: "checkmark.circle.fill", tint: BzColor.connected, text: "Rappels enregistrés sur le bracelet")
        } else if vm.connState == .ready {
            Banner(icon: "arrow.triangle.2.circlepath", tint: BzColor.connecting, text: "Envoi des rappels au bracelet…")
        } else {
            Banner(icon: "icloud.slash", tint: BzColor.disconnected, text: "Enregistrés sur le téléphone — envoyés à la connexion")
        }
    }
}
