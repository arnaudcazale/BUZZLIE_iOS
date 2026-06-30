import SwiftUI

struct ReminderEditorSheet: View {
    @ObservedObject var vm: BuzzlieViewModel
    let onDismiss: () -> Void
    private let isNew: Bool
    @State private var draft: ReminderUi

    init(vm: BuzzlieViewModel, reminderId: String?, onDismiss: @escaping () -> Void) {
        self.vm = vm
        self.onDismiss = onDismiss
        let existing = vm.reminderById(reminderId)
        self.isNew = existing == nil
        if let existing {
            _draft = State(initialValue: existing)
        } else {
            let (h, m) = Time.nextRoundHour()
            var r = ReminderUi()
            r.hour = h; r.minute = m
            _draft = State(initialValue: r)
        }
    }

    private var delayValid: Bool { draft.mode != .RELATIVE || draft.delayMinutes > 0 }

    var body: some View {
        let now = Time.nowSeconds()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                TextField("Nom (optionnel)", text: $draft.label)
                    .textFieldStyle(.roundedBorder)
                    .font(BzFont.bodyLarge)

                SegmentedControl(
                    options: [ScheduleMode.RELATIVE, ScheduleMode.ABSOLUTE],
                    selected: draft.mode,
                    label: { $0 == .RELATIVE ? "Dans un délai" : "À une heure" },
                    onSelect: { mode in
                        draft.mode = mode
                        if mode == .RELATIVE { draft.dayMask = 0 }
                    }
                )

                if draft.mode == .RELATIVE {
                    DurationPicker(
                        hours: draft.delayMinutes / 60,
                        minutes: draft.delayMinutes % 60,
                        onChange: { h, m in draft.delayMinutes = h * 60 + m }
                    )
                    let target = now + Int64(draft.delayMinutes) * 60
                    PreviewLine(
                        draft.delayMinutes <= 0 ? "Choisissez un délai"
                        : draft.repeats ? "Sonnera tous les jours à \(Time.hm(target))"
                        : "Sonnera \(Time.relativeDay(target)) à \(Time.hm(target))"
                    )
                } else {
                    WheelTimePicker(
                        hour: draft.hour,
                        minute: draft.minute,
                        onChange: { h, m in draft.hour = h; draft.minute = m }
                    )
                    let target = draft.targetEpoch(now)
                    PreviewLine(
                        draft.repeats ? "Sonnera \(daysLabel(draft.dayMask)) à \(Time.hm(target))"
                        : "Sonnera \(Time.relativeDay(target)) à \(Time.hm(target))"
                    )
                }

                if draft.mode == .ABSOLUTE {
                    Rectangle().fill(BzColor.outline).frame(height: 1)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tous les jours").font(BzFont.bodyLarge).foregroundStyle(BzColor.onSurface)
                            Text("Répéter ce rappel chaque jour")
                                .font(BzFont.bodySmall).foregroundStyle(BzColor.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: Binding(
                            get: { draft.dayMask == ALL_DAYS },
                            set: { draft.dayMask = $0 ? ALL_DAYS : 0 }
                        ))
                        .labelsHidden()
                        .tint(BzColor.primary)
                    }

                    if draft.dayMask != ALL_DAYS {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Jours (aucun = une seule fois)")
                                .font(BzFont.bodySmall).foregroundStyle(BzColor.onSurfaceVariant)
                            DayOfWeekPicker(mask: draft.dayMask, onChange: { draft.dayMask = $0 })
                        }
                    }
                }

                if !isNew {
                    Button {
                        vm.deleteReminder(draft.id); onDismiss()
                    } label: {
                        Text("Supprimer le rappel").font(BzFont.bodyLarge).foregroundStyle(BzColor.error)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, BzSpacing.screenH)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BzColor.background)
    }

    private var header: some View {
        HStack {
            Button("Annuler", action: onDismiss)
                .font(BzFont.bodyLarge).tint(BzColor.primary)
            Spacer()
            Text(isNew ? "Nouveau rappel" : "Modifier")
                .font(BzFont.titleMedium).foregroundStyle(BzColor.onSurface)
            Spacer()
            Button("Enregistrer") {
                var toSave = draft
                if toSave.mode == .RELATIVE { toSave.anchorEpoch = Time.nowSeconds() }
                if isNew { vm.addReminder(toSave) } else { vm.updateReminder(toSave) }
                onDismiss()
            }
            .font(BzFont.bodyLarge).tint(BzColor.primary)
            .disabled(!delayValid)
        }
        .padding(.top, 12)
    }

    private func PreviewLine(_ text: String) -> some View {
        Text(text)
            .font(BzFont.titleMedium)
            .foregroundStyle(BzColor.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
