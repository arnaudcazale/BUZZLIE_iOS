import XCTest
@testable import BuzzlieTest

final class ConfigCodecTests: XCTestCase {

    /// testPreset(now): 1 daily reminder at now+120, saccade 500/500, 30s, adv 30.
    /// Expected blob byte-for-byte (little-endian), with now=0 for determinism.
    func testEncodeTestPreset() throws {
        let now: Int64 = 0
        let blob = try ConfigCodec.encodeConfig(ConfigCodec.testPreset(now))
        // ver=1 | nEntries=1 | epoch=120 (78 00 00 00) | dayMask=0x7F |
        // nSteps=1 | on=500(F4 01) | off=500(F4 01) | effect=0 | dur=30000(30 75) | adv=30(1E)
        let expected: [UInt8] = [
            0x01,
            0x01,
            0x78, 0x00, 0x00, 0x00, 0x7F,
            0x01,
            0xF4, 0x01, 0xF4, 0x01, 0x00, 0x30, 0x75,
            0x1E,
        ]
        XCTAssertEqual(blob, expected)
    }

    /// Round-trip: encode then decode must reproduce the draft.
    func testRoundTrip() throws {
        let draft = ConfigDraft(
            reminders: [
                Reminder(epochSeconds: 1_700_000_000, dayMask: 0x7F),
                Reminder(epochSeconds: 1_700_003_600, dayMask: 0x1F),
                Reminder(epochSeconds: 1_700_007_200, dayMask: 0),
            ],
            steps: [HapticStep(onMs: 300, offMs: 700, effectId: 0, totalDurationMs: 10_000)],
            advDurationS: 30
        )
        let blob = try ConfigCodec.encodeConfig(draft)
        let decoded = ConfigCodec.decodeConfig(blob)
        XCTAssertEqual(decoded, draft)
    }

    func testTimeSyncEncoding() {
        // epoch 1 → 01 00 00 00
        XCTAssertEqual(ConfigCodec.encodeTimeSync(1), [0x01, 0x00, 0x00, 0x00])
        // epoch 0x01020304 → 04 03 02 01
        XCTAssertEqual(ConfigCodec.encodeTimeSync(0x01020304), [0x04, 0x03, 0x02, 0x01])
    }

    func testStatusDecode() {
        // vbat=3700(0x0E74→74 0E) | %=88 | flags=0x0B | fw 1.2.3 | bonds=2
        let bytes: [UInt8] = [0x74, 0x0E, 88, 0x0B, 1, 2, 3, 2]
        let s = ConfigCodec.decodeStatus(bytes)
        XCTAssertEqual(s?.vbatMv, 3700)
        XCTAssertEqual(s?.percent, 88)
        XCTAssertEqual(s?.fwVersion, "1.2.3")
        XCTAssertEqual(s?.bondCount, 2)
        XCTAssertTrue(s?.configValid ?? false)   // 0x01
        XCTAssertTrue(s?.lowBatt ?? false)        // 0x02
        XCTAssertTrue(s?.timeSynced ?? false)     // 0x08
        XCTAssertFalse(s?.critBatt ?? true)       // 0x04 not set
    }

    func testControlEncoding() {
        XCTAssertEqual(ConfigCodec.encodeControl(0x03), [0x03])
        XCTAssertEqual(ConfigCodec.encodeControl(0x01, param: 5), [0x01, 0x05])
    }

    /// weekdayMon0 must match the firmware formula ((epoch/86400)+3)%7, Monday=0.
    func testWeekday() {
        // 2021-01-04 00:00 UTC is a Monday. epoch = 1609718400.
        XCTAssertEqual(Time.weekdayMon0(1_609_718_400), 0)
        // +1 day → Tuesday
        XCTAssertEqual(Time.weekdayMon0(1_609_718_400 + 86_400), 1)
        // +6 days → Sunday
        XCTAssertEqual(Time.weekdayMon0(1_609_718_400 + 6 * 86_400), 6)
    }
}
