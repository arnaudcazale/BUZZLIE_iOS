import Foundation

/// Everything the app persists locally. Vibration settings are adopted FROM the
/// bracelet at connection (0xB005 read-back) unless locally edited since the last
/// sync (vibrationDirty).
struct AppSettings: Codable, Equatable {
    var reminders: [ReminderUi] = []
    var intensity: VibrationPreset = .STANDARD
    var continuous: Bool = false
    var alarmDurationSec: Int = 10
    var advDurationS: Int = 30
    /// Reglages vibration modifies localement, pas encore pousses au bracelet :
    /// a la connexion, la valeur locale GAGNE (sinon le bracelet fait foi).
    /// Optionnel pour tolerer les JSON persistes sans la cle (nil = false).
    var vibrationDirty: Bool? = false
}
