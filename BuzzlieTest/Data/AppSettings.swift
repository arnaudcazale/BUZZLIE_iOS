import Foundation

/// Everything the app persists locally (the device config is write-only).
struct AppSettings: Codable, Equatable {
    var reminders: [ReminderUi] = []
    var intensity: VibrationPreset = .STANDARD
    var continuous: Bool = false
    var alarmDurationSec: Int = 10
    var advDurationS: Int = 30
}
