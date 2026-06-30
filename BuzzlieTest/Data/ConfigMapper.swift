import Foundation

/// Builds the firmware ConfigDraft from the persisted settings:
///  - relative reminders use their fixed anchor (don't slide on reconnect),
///  - expired one-shots are dropped,
///  - capped at MAX_ENTRIES,
///  - one shared haptic pattern resolved from the global vibration preset.
extension AppSettings {
    func toConfigDraft(_ now: Int64) -> ConfigDraft {
        let entries = reminders
            .filter { $0.enabled && !$0.isExpired(now) }
            .prefix(BuzzlieGatt.maxEntries)
            .map { Reminder(epochSeconds: $0.targetEpoch(now), dayMask: $0.dayMask) }

        return ConfigDraft(
            reminders: Array(entries),
            steps: resolveSteps(intensity, continuous, alarmDurationSec),
            advDurationS: advDurationS
        )
    }
}

/// Removes one-shot reminders whose time has already passed (local auto-cleanup).
func withoutExpired(_ list: [ReminderUi], _ now: Int64) -> [ReminderUi] {
    list.filter { !$0.isExpired(now) }
}

/// Tolerance (seconds) for considering a device one-shot the same as a local one.
private let ONE_SHOT_MATCH_TOLERANCE_S: Int64 = 60

extension Reminder {
    /// Imports a device alarm (epoch + day_mask, no label) into the editable UI model.
    /// Represented as ABSOLUTE at the device epoch's local wall-clock time; repeat mask kept.
    func toReminderUi(_ now: Int64) -> ReminderUi {
        let (h, m) = Time.hourMinuteOf(epochSeconds)
        return ReminderUi(mode: .ABSOLUTE, hour: h, minute: m, dayMask: dayMask, enabled: true)
    }
}

private extension ReminderUi {
    /// True if a local reminder already represents this device alarm (same firing identity).
    func represents(_ dev: Reminder, _ now: Int64) -> Bool {
        if dayMask != dev.dayMask { return false }
        if dev.dayMask != 0 {
            return Time.minutesOfDay(targetEpoch(now)) == Time.minutesOfDay(dev.epochSeconds)
        } else {
            return abs(targetEpoch(now) - dev.epochSeconds) <= ONE_SHOT_MATCH_TOLERANCE_S
        }
    }
}

/// Reconciles the local reminder list with what the bracelet currently has (union,
/// bracelet preserved). Device alarms not already represented locally are imported so a
/// second phone / fresh install never wipes them. Expired device one-shots are dropped.
/// Result is capped at MAX_ENTRIES, keeping dailies first then the nearest one-shots.
func mergeSchedule(_ local: [ReminderUi], _ device: ConfigDraft?, _ now: Int64) -> [ReminderUi] {
    guard let device else { return local }

    let liveDeviceEntries = device.reminders.filter { $0.dayMask != 0 || $0.epochSeconds > now }
    let imported = liveDeviceEntries
        .filter { dev in !local.contains { $0.represents(dev, now) } }
        .map { $0.toReminderUi(now) }

    let merged = local + imported
    if merged.count <= BuzzlieGatt.maxEntries { return merged }

    // Over the firmware cap: keep all repeating reminders, then the soonest one-shots.
    let repeating = merged.filter { $0.repeats }
    let oneShots = merged.filter { !$0.repeats }
    let slots = max(BuzzlieGatt.maxEntries - repeating.count, 0)
    let keptOneShots = oneShots.sorted { $0.targetEpoch(now) < $1.targetEpoch(now) }.prefix(slots)
    return Array((repeating + keptOneShots).prefix(BuzzlieGatt.maxEntries))
}
