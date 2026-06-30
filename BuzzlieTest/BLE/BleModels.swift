import Foundation

/// A scheduled reminder = a time + a weekday repeat mask (bit0=Mon..bit6=Sun ; 0 = one-shot).
struct Reminder: Equatable {
    let epochSeconds: Int64
    let dayMask: Int
}

/// One haptic step of the vibration pattern. off_ms == 0 means continuous.
struct HapticStep: Equatable {
    var onMs: Int = 500
    var offMs: Int = 500
    var effectId: Int = 0             // 0 = RTP, 1..123 = DRV2605L ROM effect
    var totalDurationMs: Int = 30_000 // 30000..60000
}

/// The full config draft the editor builds and the codec encodes into the blob.
struct ConfigDraft: Equatable {
    var reminders: [Reminder] = []
    var steps: [HapticStep] = [HapticStep()]
    var advDurationS: Int = 30
}

/// Decoded 8-byte Status characteristic (0xB003).
struct StatusFrame: Equatable {
    let vbatMv: Int
    let percent: Int
    let flags: Int
    let fwMajor: Int
    let fwMinor: Int
    let fwPatch: Int
    let bondCount: Int

    var fwVersion: String { "\(fwMajor).\(fwMinor).\(fwPatch)" }
    var configValid: Bool { flags & BuzzlieGatt.flagConfigValid != 0 }
    var lowBatt: Bool { flags & BuzzlieGatt.flagLowBatt != 0 }
    var critBatt: Bool { flags & BuzzlieGatt.flagCritBatt != 0 }
    var timeSynced: Bool { flags & BuzzlieGatt.flagTimeSynced != 0 }
}

/// Coarse connection state surfaced to the UI.
enum ConnState { case disconnected, connecting, connected, ready, failed }

enum LogLevel { case op, notify, error }

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timeMs: Int64
    let level: LogLevel
    let message: String
}

struct ScanDevice: Equatable {
    let name: String
    let address: String
    let rssi: Int
}
