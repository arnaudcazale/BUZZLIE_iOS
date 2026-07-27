import XCTest
@testable import BuzzlieTest

/// Bug "one-shot fantôme" (constaté 2026-07-27) : une ABSOLUTE ponctuelle sans date figée
/// recalculait "la prochaine occurrence" (toujours future) → jamais expirée, re-poussée
/// au bracelet à chaque connexion, et re-sonnait le lendemain. Miroir de ConfigMapperTest.kt.
final class ConfigMapperTests: XCTestCase {

    func testAbsoluteOneShotWithPastFrozenTargetIsExpiredAndDropped() {
        let now = Time.nowSeconds()

        var fired = ReminderUi(mode: .ABSOLUTE, hour: 8, minute: 0)   // a sonné il y a 1 h
        fired.targetEpochFixed = now - 3600

        XCTAssertTrue(fired.isExpired(now))
        XCTAssertTrue(withoutExpired([fired], now).isEmpty)

        var settings = AppSettings()
        settings.reminders = [fired]
        XCTAssertTrue(settings.toConfigDraft(now).reminders.isEmpty)
    }

    func testAbsoluteOneShotWithFutureFrozenTargetKeepsStableEpoch() {
        let now = Time.nowSeconds()
        let target = now + 7200                                        // dans 2 h

        var pending = ReminderUi(mode: .ABSOLUTE, hour: 8, minute: 0)
        pending.targetEpochFixed = target

        XCTAssertFalse(pending.isExpired(now))
        // La cible ne "glisse" pas : même epoch quelle que soit l'heure de lecture.
        XCTAssertEqual(pending.targetEpoch(now), target)
        XCTAssertEqual(pending.targetEpoch(now + 3600), target)

        var settings = AppSettings()
        settings.reminders = [pending]
        XCTAssertEqual(settings.toConfigDraft(now).reminders.first?.epochSeconds, target)
    }

    func testDailyAbsoluteIgnoresFrozenTargetAndNeverExpires() {
        let now = Time.nowSeconds()
        let daily = ReminderUi(mode: .ABSOLUTE, hour: 8, minute: 0, dayMask: ALL_DAYS)

        XCTAssertFalse(daily.isExpired(now))
        XCTAssertGreaterThan(daily.targetEpoch(now), now)
    }

    func testLegacyJsonWithoutTargetEpochFixedStillDecodes() {
        // Rappel enregistré AVANT l'ajout du champ : le décodage ne doit pas échouer
        // (un keyNotFound ferait repartir load() d'un AppSettings vierge = rappels perdus).
        let json = #"{"id":"x","label":"","mode":"ABSOLUTE","delayMinutes":210,"hour":8,"minute":0,"dayMask":0,"anchorEpoch":0,"enabled":true}"#
        let decoded = try? JSONDecoder().decode(ReminderUi.self, from: Data(json.utf8))

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.targetEpochFixed, 0)
        XCTAssertEqual(decoded?.hour, 8)
    }
}
