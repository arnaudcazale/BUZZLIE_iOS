import Foundation

/// Encodes/decodes the BUZZLIE wire payloads. ALL little-endian, matching the firmware
/// (ble_buzzlie.c config_blob_parse / ble_buzzlie_status_update).
enum ConfigCodec {

    struct EncodeError: Error { let message: String }

    // MARK: - little-endian append helpers

    private static func appendU16LE(_ buf: inout [UInt8], _ value: Int) {
        let v = UInt16(truncatingIfNeeded: value)
        buf.append(UInt8(v & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
    }

    private static func appendU32LE(_ buf: inout [UInt8], _ value: Int64) {
        let v = UInt32(truncatingIfNeeded: value)
        buf.append(UInt8(v & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8((v >> 16) & 0xFF))
        buf.append(UInt8((v >> 24) & 0xFF))
    }

    /// Config blob layout:
    ///   u8 version(=1) | u8 entry_count | entry_count x { u32 epoch ; u8 day_mask }
    ///   | u8 haptic_steps | haptic_steps x { u16 on ; u16 off ; u8 effect ; u16 total }
    ///   | u8 adv_duration_s
    static func encodeConfig(_ draft: ConfigDraft) throws -> [UInt8] {
        guard draft.reminders.count <= BuzzlieGatt.maxEntries else {
            throw EncodeError(message: "max \(BuzzlieGatt.maxEntries) reminders")
        }
        guard !draft.steps.isEmpty, draft.steps.count <= BuzzlieGatt.maxSteps else {
            throw EncodeError(message: "haptic steps must be 1..\(BuzzlieGatt.maxSteps)")
        }
        guard BuzzlieGatt.advDurationSRange.contains(draft.advDurationS) else {
            throw EncodeError(message: "adv_duration_s must be \(BuzzlieGatt.advDurationSRange)")
        }
        for s in draft.steps {
            if s.effectId != 0 && !(1...123).contains(s.effectId) {
                throw EncodeError(message: "effect_id must be 0 (RTP) or 1..123")
            }
            if !BuzzlieGatt.durationMsRange.contains(s.totalDurationMs) {
                throw EncodeError(message: "total_duration_ms must be \(BuzzlieGatt.durationMsRange)")
            }
        }

        var buf = [UInt8]()
        buf.reserveCapacity(BuzzlieGatt.configWireMax)
        buf.append(1)                                  // version
        buf.append(UInt8(truncatingIfNeeded: draft.reminders.count)) // entry_count
        for r in draft.reminders {
            appendU32LE(&buf, r.epochSeconds)          // u32 (low 32 bits of epoch)
            buf.append(UInt8(r.dayMask & 0x7F))        // u8 day_mask
        }
        buf.append(UInt8(truncatingIfNeeded: draft.steps.count)) // haptic_steps
        for s in draft.steps {
            appendU16LE(&buf, s.onMs)
            appendU16LE(&buf, s.offMs)
            buf.append(UInt8(truncatingIfNeeded: s.effectId))
            appendU16LE(&buf, s.totalDurationMs)
        }
        buf.append(UInt8(truncatingIfNeeded: draft.advDurationS)) // adv_duration_s

        guard buf.count <= BuzzlieGatt.configWireMax else {
            throw EncodeError(message: "blob \(buf.count) B exceeds \(BuzzlieGatt.configWireMax)")
        }
        return buf
    }

    /// Inverse of `encodeConfig`: parses the Schedule (B005) read-back blob, which uses
    /// the exact same wire layout as the Config write. Returns nil if malformed/truncated.
    static func decodeConfig(_ bytes: [UInt8]) -> ConfigDraft? {
        if bytes.count < 2 { return nil }
        var r = ByteReader(bytes)
        guard r.u8() == 1 else { return nil }                  // version
        guard let nEntries = r.u8(), nEntries <= BuzzlieGatt.maxEntries else { return nil }
        if r.remaining < nEntries * 5 + 1 { return nil }
        var reminders = [Reminder]()
        for _ in 0..<nEntries {
            guard let epoch = r.u32(), let dayMask = r.u8() else { return nil }
            reminders.append(Reminder(epochSeconds: Int64(epoch), dayMask: dayMask & 0x7F))
        }
        guard let nSteps = r.u8(), nSteps != 0, nSteps <= BuzzlieGatt.maxSteps else { return nil }
        if r.remaining < nSteps * 7 + 1 { return nil }
        var steps = [HapticStep]()
        for _ in 0..<nSteps {
            guard let on = r.u16(), let off = r.u16(), let effect = r.u8(), let total = r.u16() else { return nil }
            steps.append(HapticStep(onMs: on, offMs: off, effectId: effect, totalDurationMs: total))
        }
        guard let advS = r.u8() else { return nil }
        return ConfigDraft(reminders: reminders, steps: steps, advDurationS: advS)
    }

    /// TimeSync payload: u32 LE current epoch (seconds).
    static func encodeTimeSync(_ epochSeconds: Int64) -> [UInt8] {
        var buf = [UInt8]()
        appendU32LE(&buf, epochSeconds)
        return buf
    }

    /// Control payload: opcode [+ optional param].
    static func encodeControl(_ opcode: Int, param: Int? = nil) -> [UInt8] {
        if let param { return [UInt8(truncatingIfNeeded: opcode), UInt8(truncatingIfNeeded: param)] }
        return [UInt8(truncatingIfNeeded: opcode)]
    }

    /// Decodes the 8-byte Status characteristic. Returns nil if too short.
    static func decodeStatus(_ bytes: [UInt8]) -> StatusFrame? {
        if bytes.count < 8 { return nil }
        var r = ByteReader(bytes)
        guard let vbat = r.u16(), let percent = r.u8(), let flags = r.u8(),
              let maj = r.u8(), let min = r.u8(), let patch = r.u8(), let bonds = r.u8() else { return nil }
        return StatusFrame(vbatMv: vbat, percent: percent, flags: flags,
                           fwMajor: maj, fwMinor: min, fwPatch: patch, bondCount: bonds)
    }

    /// Battery Level (0x2A19): single u8 percent.
    static func decodeBattery(_ bytes: [UInt8]) -> Int? {
        bytes.isEmpty ? nil : Int(bytes[0])
    }

    /// The exact TEST_DK §6 preset: 1 daily reminder at now+120s, saccade 500/500, 30s, adv 30.
    static func testPreset(_ nowSeconds: Int64) -> ConfigDraft {
        ConfigDraft(
            reminders: [Reminder(epochSeconds: nowSeconds + 120, dayMask: 0x7F)],
            steps: [HapticStep(onMs: 500, offMs: 500, effectId: 0, totalDurationMs: 30_000)],
            advDurationS: 30
        )
    }

    static func toHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

/// Little-endian sequential reader over a byte array.
private struct ByteReader {
    private let bytes: [UInt8]
    private var index = 0
    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var remaining: Int { bytes.count - index }

    mutating func u8() -> Int? {
        guard index + 1 <= bytes.count else { return nil }
        defer { index += 1 }
        return Int(bytes[index])
    }
    mutating func u16() -> Int? {
        guard index + 2 <= bytes.count else { return nil }
        defer { index += 2 }
        return Int(bytes[index]) | (Int(bytes[index + 1]) << 8)
    }
    mutating func u32() -> UInt32? {
        guard index + 4 <= bytes.count else { return nil }
        defer { index += 4 }
        return UInt32(bytes[index]) | (UInt32(bytes[index + 1]) << 8)
            | (UInt32(bytes[index + 2]) << 16) | (UInt32(bytes[index + 3]) << 24)
    }
}
