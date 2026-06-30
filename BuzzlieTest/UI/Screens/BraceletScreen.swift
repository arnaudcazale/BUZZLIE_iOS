import SwiftUI

struct BraceletScreen: View {
    @ObservedObject var vm: BuzzlieViewModel
    let onConnect: () -> Void

    private var ready: Bool { vm.connState == .ready }

    var body: some View {
        ScreenScaffold {
            ScreenHeader("Bracelet")

            ConnectionBanner(conn: vm.connState, onConnect: onConnect, onDisconnect: { vm.disconnect() })

            VStack(spacing: 0) {
                BatteryRing(percent: ready ? vm.battery : nil)
                Text(ready && vm.status != nil ? "Firmware \(vm.status!.fwVersion)" : "Non connecté")
                    .font(BzFont.bodyMedium)
                    .foregroundStyle(BzColor.onSurfaceVariant)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            InsetGroup(
                "Vibration",
                footer: ready ? "Ce réglage s'applique à tous les rappels."
                    : "Connectez le bracelet pour régler et tester la vibration."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Intensité")
                    SegmentedControl(
                        options: VibrationPreset.allCases,
                        selected: vm.settings.intensity,
                        label: { $0.label },
                        onSelect: { vm.setVibration($0, vm.settings.continuous) },
                        enabled: ready
                    )

                    sectionLabel("Style").padding(.top, 8)
                    SegmentedControl(
                        options: [false, true],
                        selected: vm.settings.continuous,
                        label: { $0 ? "Continu" : "Saccadé" },
                        onSelect: { vm.setVibration(vm.settings.intensity, $0) },
                        enabled: ready
                    )

                    sectionLabel("Durée").padding(.top, 8)
                    DurationSlider(
                        seconds: vm.settings.alarmDurationSec,
                        onChange: { vm.setAlarmDuration($0) },
                        range: BuzzlieGatt.alarmDurationSRange,
                        enabled: ready
                    )

                    Button {
                        vm.testVibration()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill").font(.system(size: 16))
                            Text("Tester la vibration").font(BzFont.labelLarge)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(BzColor.primary)
                    .disabled(!ready)
                    .padding(.top, 12)
                }
                .padding(BzSpacing.cardInset)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(BzFont.labelMedium).foregroundStyle(BzColor.onSurfaceVariant)
    }
}
