import Foundation

enum Time {

    static func nowSeconds() -> Int64 { Int64(Date().timeIntervalSince1970) }

    private static var cal: Calendar { Calendar.current }

    /// Next future occurrence (epoch seconds, local wall-clock) of the given hour:minute.
    /// If that time already passed today, returns tomorrow's.
    static func nextOccurrence(_ hour: Int, _ minute: Int) -> Int64 {
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        var date = cal.date(from: comps) ?? now
        if date <= now {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return Int64(date.timeIntervalSince1970)
    }

    /// Next occurrence of hour:minute landing on a masked weekday (bit0=Mon..bit6=Sun).
    /// Empty mask (one-shot) → just the next occurrence. Weekday is derived from the epoch
    /// the same way the firmware does, so app↔bracelet agree on re-arm day.
    static func nextOccurrenceOnDays(_ hour: Int, _ minute: Int, _ dayMask: Int) -> Int64 {
        var t = nextOccurrence(hour, minute)
        if dayMask & 0x7F == 0 { return t }
        for _ in 0..<7 {
            if (dayMask >> weekdayMon0(t)) & 1 != 0 { return t }
            t += 86_400
        }
        return t
    }

    /// Weekday derived from epoch: Monday=0 … Sunday=6 (same formula as the firmware, UTC days).
    static func weekdayMon0(_ epochSeconds: Int64) -> Int {
        Int(((epochSeconds / 86_400) + 3) % 7)
    }

    /// Next round (top-of-the-)hour still to come, minutes = 0. Default for new absolute reminders.
    static func nextRoundHour() -> (Int, Int) {
        let h = cal.component(.hour, from: Date())
        return ((h + 1) % 24, 0)
    }

    /// "aujourd'hui" / "demain" / "le dd/MM" of an epoch, relative to now (local days).
    static func relativeDay(_ epochSeconds: Int64) -> String {
        let target = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: target)).day ?? 0
        switch days {
        case 0: return "aujourd'hui"
        case 1: return "demain"
        default: return "le " + dayFmt.string(from: target)
        }
    }

    /// Local wall-clock (hour, minute) of an epoch — used to import device alarms.
    static func hourMinuteOf(_ epochSeconds: Int64) -> (Int, Int) {
        let date = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }

    /// Minutes since local midnight (0..1439) — used to dedup daily alarms by time-of-day.
    static func minutesOfDay(_ epochSeconds: Int64) -> Int {
        let (h, m) = hourMinuteOf(epochSeconds)
        return h * 60 + m
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd/MM"; return f
    }()
    private static let hmFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    private static let clockFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    static func hm(_ epochSeconds: Int64) -> String {
        hmFmt.string(from: Date(timeIntervalSince1970: TimeInterval(epochSeconds)))
    }
    /// Clock string from epoch MILLISECONDS (log timestamps).
    static func clock(_ epochMs: Int64) -> String {
        clockFmt.string(from: Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000))
    }
}
