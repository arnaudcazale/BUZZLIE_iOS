import CoreBluetooth

/// Single source of truth for the BUZZLIE GATT contract.
///
/// Custom base UUID (firmware ble_buzzlie.h): B0220000-5A1E-4D6B-9E2F-C0DEBA77E51E,
/// with the 16-bit id substituted into the "0000" slot.
enum BuzzlieGatt {

    private static func uuid(_ id16: String) -> CBUUID {
        CBUUID(string: "B022\(id16)-5A1E-4D6B-9E2F-C0DEBA77E51E")
    }

    static let service   = uuid("B000")
    static let config    = uuid("B001") // WRITE, var-len, max 100 B (long write)
    static let timeSync  = uuid("B002") // WRITE, 4 B (u32 LE epoch)
    static let status    = uuid("B003") // READ + NOTIFY, 8 B
    static let control   = uuid("B004") // WRITE, 1..2 B
    static let schedule  = uuid("B005") // READ + NOTIFY, same blob as CONFIG (read-back)

    // Standard Battery Service
    static let batteryService = CBUUID(string: "180F")
    static let batteryLevel   = CBUUID(string: "2A19")

    static let namePrefix = "BUZZLIE-"

    // Control opcodes
    static let ctrlAllowNewBond = 0x01
    static let ctrlForgetBond   = 0x02
    static let ctrlTestHaptic   = 0x03 // play the current haptic pattern now (no flash, no alarm)

    // Status flag bit masks
    static let flagConfigValid = 0x01
    static let flagLowBatt     = 0x02
    static let flagCritBatt    = 0x04
    static let flagTimeSynced  = 0x08

    // Config blob limits (firmware flash_config.h / ble_buzzlie.h)
    static let maxEntries = 8
    static let maxSteps   = 8
    static let configWireMax = 100
    static let durationMsRange = 1_000...30_000
    static let advDurationSRange = 10...60
    // User-facing alarm vibration duration (seconds). Maps to a step's total_duration_ms.
    static let alarmDurationSRange = 1...30
}
