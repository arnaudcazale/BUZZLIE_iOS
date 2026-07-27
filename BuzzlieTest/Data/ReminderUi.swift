import Foundation

enum ScheduleMode: String, Codable { case RELATIVE, ABSOLUTE }

/// Weekday mask: bit0=Monday … bit6=Sunday. 0 = one-shot, 0x7F = every day.
let ALL_DAYS = 0x7F
private let DAY_SHORT = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]

/// Compact label for a day mask ("Tous les jours", "En semaine", "Lun, Mer, Ven", …).
func daysLabel(_ mask: Int) -> String {
    switch mask & ALL_DAYS {
    case ALL_DAYS: return "Tous les jours"
    case 0x1F: return "En semaine"
    case 0x60: return "Le week-end"
    case 0: return ""
    default:
        return (0..<7).filter { mask & (1 << $0) != 0 }.map { DAY_SHORT[$0] }.joined(separator: ", ")
    }
}

/// A reminder as the user edits it. The device only stores absolute epochs (write-only config),
/// so this UI-level model is the source of truth and is persisted locally.
struct ReminderUi: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var label: String = ""
    var mode: ScheduleMode = .ABSOLUTE
    var delayMinutes: Int = 210     // RELATIVE: e.g. 3h30 = 210
    var hour: Int = 8               // ABSOLUTE
    var minute: Int = 0             // ABSOLUTE
    var dayMask: Int = 0            // repeat days (bit0=Mon..bit6=Sun) ; 0 = one-shot
    var anchorEpoch: Int64 = 0     // RELATIVE: set-time, so the target is fixed (not sliding)
    var targetEpochFixed: Int64 = 0 // ABSOLUTE one-shot: target date frozen at save (0 = legacy, recompute)
    var enabled: Bool = true

    /// True if the reminder repeats (at least one selected day).
    var repeats: Bool { dayMask & ALL_DAYS != 0 }

    /// Absolute epoch this reminder targets (seconds).
    func targetEpoch(_ now: Int64) -> Int64 {
        switch mode {
        case .RELATIVE: return anchorEpoch + Int64(delayMinutes) * 60
        // One-shot : date figée au save — sans elle, "prochaine occurrence" glisse à J+1
        // chaque jour et isExpired() ne devient jamais vrai (alarme fantôme éternelle).
        case .ABSOLUTE:
            if !repeats && targetEpochFixed != 0 { return targetEpochFixed }
            return Time.nextOccurrenceOnDays(hour, minute, dayMask)
        }
    }

    /// One-shot whose target already passed → expired (dropped before sending).
    func isExpired(_ now: Int64) -> Bool { !repeats && targetEpoch(now) <= now }

    /// Human title for the card / preview.
    func whenLabel(_ now: Int64) -> String {
        let base: String
        switch true {
        case mode == .ABSOLUTE && repeats:
            base = String(format: "\(daysLabel(dayMask)) à %02d:%02d", hour, minute)
        case mode == .ABSOLUTE:
            base = String(format: "À %02d:%02d", hour, minute)
        case repeats:
            base = "Chaque jour, dans \(durationLabel())"
        default:
            base = "Dans \(durationLabel())"
        }
        return label.isEmpty ? base : "\(label) · \(base)"
    }

    func durationLabel() -> String {
        let h = delayMinutes / 60
        let m = delayMinutes % 60
        switch true {
        case h > 0 && m > 0: return "\(h) h \(m) min"
        case h > 0: return "\(h) h"
        default: return "\(m) min"
        }
    }
}

extension ReminderUi {
    /// Décodage tolérant : le Codable synthétisé lève keyNotFound sur un champ absent,
    /// et load() repartirait alors d'un AppSettings vierge (perte de tous les rappels).
    /// Indispensable pour les JSON enregistrés avant l'ajout de targetEpochFixed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        mode = try c.decodeIfPresent(ScheduleMode.self, forKey: .mode) ?? .ABSOLUTE
        delayMinutes = try c.decodeIfPresent(Int.self, forKey: .delayMinutes) ?? 210
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 8
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        dayMask = try c.decodeIfPresent(Int.self, forKey: .dayMask) ?? 0
        anchorEpoch = try c.decodeIfPresent(Int64.self, forKey: .anchorEpoch) ?? 0
        targetEpochFixed = try c.decodeIfPresent(Int64.self, forKey: .targetEpochFixed) ?? 0
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}
