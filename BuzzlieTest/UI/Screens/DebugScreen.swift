import SwiftUI

struct DebugScreen: View {
    @ObservedObject var vm: BuzzlieViewModel
    let onConnect: () -> Void

    private var ready: Bool { vm.connState == .ready }

    private var connName: String {
        switch vm.connState {
        case .ready: return "Ready"
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .failed: return "Failed"
        case .disconnected: return "Disconnected"
        }
    }

    var body: some View {
        let (hex, len) = vm.encodedPreview()
        ScreenScaffold {
            ScreenHeader("Debug")

            InsetGroup("Connexion") {
                SettingsRow(ready ? "Connecté (\(connName))" : "Connecter / scanner", onClick: onConnect)
                if ready {
                    RowDivider()
                    SettingsRow("Déconnecter", onClick: { vm.disconnect() })
                }
            }

            InsetGroup("Status (0xB003)") {
                VStack(alignment: .leading, spacing: 8) {
                    if let s = vm.status {
                        Text("\(s.vbatMv) mV · \(s.percent) % · fw \(s.fwVersion) · bonds \(s.bondCount)")
                            .font(BzFont.bodyMedium).foregroundStyle(BzColor.onSurface)
                        StatusChips(status: s)
                    } else {
                        Text("—").font(BzFont.bodyMedium).foregroundStyle(BzColor.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BzSpacing.cardInset)
            }

            InsetGroup("Heure & Config") {
                SettingsRow("Sync heure", enabled: ready, onClick: { vm.syncTimeNow() })
                RowDivider()
                SettingsRow("Envoyer config brute", enabled: ready, onClick: { vm.sendConfig() })
                RowDivider()
                SettingsRow("Preset test +120 s", enabled: ready, onClick: { vm.sendTestPreset() })
                RowDivider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blob (\(len >= 0 ? "\(len)" : "?")/100 o)")
                        .font(BzFont.labelSmall).foregroundStyle(BzColor.onSurfaceVariant)
                    Text(hex).font(.system(size: 13, design: .monospaced)).foregroundStyle(BzColor.onSurface)
                    if len > 20 {
                        Text("> 20 o → MTU 247, un seul write (QWR en repli).")
                            .font(BzFont.bodySmall).foregroundStyle(BzColor.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BzSpacing.cardInset)
            }

            InsetGroup("Bonding") {
                SettingsRow("Allow new bond (0x01)", enabled: ready, onClick: { vm.allowNewBond() })
                RowDivider()
                SettingsRow("Forget bonds (0x02)", enabled: ready, onClick: { vm.forgetBonds() })
            }

            LogConsole(log: vm.log, onClear: { vm.clearLog() })
        }
    }
}
