import XCTest
@testable import UsageCore

final class AlertPolicyTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-10-31T20:00:00Z")!
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func provider(_ amount: Double, fetched: Date? = nil) -> ProviderUsage {
        ProviderUsage(name: "Claude", weekly: UsageWindow(remaining: amount, reset: now.addingTimeInterval(4 * 86400), duration: 7 * 86400), session: nil, fetchedAt: fetched ?? now, message: nil)
    }
    func testThresholdsAndDailyDedupe() {
        for (amount, word) in [(20.0, "handoff"), (10.0, "wrap"), (0.0, "exhausted")] {
            let alert = AlertPolicy.alerts(for: [provider(amount)], now: now, calendar: calendar).first!
            XCTAssertTrue(alert.id.contains(word))
            XCTAssertTrue(AlertPolicy.alerts(for: [provider(amount)], now: now, calendar: calendar, sent: [alert.id]).isEmpty)
        }
    }
    func testCodexLowUsageAlerts() {
        for (amount, severity) in [(20.0, "handoff"), (10.0, "wrap"), (0.0, "exhausted")] {
            let p = ProviderUsage(name: "Codex", weekly: UsageWindow(remaining: amount, reset: now.addingTimeInterval(86400), duration: 604800), session: nil, fetchedAt: now, message: nil)
            let alert = AlertPolicy.alerts(for: [p], now: now, calendar: calendar).first!
            XCTAssertTrue(alert.id.contains(severity))
        }
    }
    func testStaleSuppressesAndSessionIsSeparate() {
        XCTAssertTrue(AlertPolicy.alerts(for: [provider(1, fetched: now.addingTimeInterval(-901))], now: now, calendar: calendar).isEmpty)
        let p = ProviderUsage(name: "Codex", weekly: nil, session: UsageWindow(remaining: 10, reset: now.addingTimeInterval(300), duration: 18000), fetchedAt: now, message: nil)
        XCTAssertTrue(AlertPolicy.alerts(for: [p], now: now, calendar: calendar)[0].id.contains("session"))
    }
    func testUnderuseRequiresHealthySessionAndBedtimeProximity() {
        let weekly = UsageWindow(remaining: 95, reset: now.addingTimeInterval(4 * 86400), duration: 7 * 86400)
        let session = UsageWindow(remaining: 90, reset: now.addingTimeInterval(3600), duration: 18000)
        let p = ProviderUsage(name: "Codex", weekly: weekly, session: session, fetchedAt: now, message: nil)
        let claude = ProviderUsage(name: "Claude", weekly: UsageWindow(remaining: 1, reset: now.addingTimeInterval(4 * 86400), duration: 7 * 86400), session: session, fetchedAt: now, message: nil)
        XCTAssertTrue(AlertPolicy.alerts(for: [p, claude], now: now, calendar: calendar).contains { $0.id.contains("room") })
        let missing = ProviderUsage(name: "Codex", weekly: weekly, session: nil, fetchedAt: now, message: nil)
        XCTAssertTrue(AlertPolicy.alerts(for: [missing, claude], now: now, calendar: calendar).contains { $0.id.contains("room") })
        let exhausted = ProviderUsage(name: "Codex", weekly: weekly, session: UsageWindow(remaining: 0, reset: now.addingTimeInterval(3600), duration: 18000), fetchedAt: now, message: nil)
        XCTAssertFalse(AlertPolicy.alerts(for: [exhausted, claude], now: now, calendar: calendar).contains { $0.id.contains("room") })
        let expired = ProviderUsage(name: "Codex", weekly: weekly, session: UsageWindow(remaining: 90, reset: now.addingTimeInterval(-1), duration: 18000), fetchedAt: now, message: nil)
        XCTAssertFalse(AlertPolicy.alerts(for: [expired, claude], now: now, calendar: calendar).contains { $0.id.contains("room") })
    }
    func testCacheIdentityChangeNeverMatches() {
        XCTAssertTrue(CacheIdentity.matches(stored: "a", current: "a"))
        XCTAssertFalse(CacheIdentity.matches(stored: "a", current: "b"))
        XCTAssertFalse(CacheIdentity.matches(stored: nil, current: "a"))
        XCTAssertTrue(CacheIdentity.retryApplies(stored: "a", current: "a", deadline: now.addingTimeInterval(60), now: now))
        XCTAssertFalse(CacheIdentity.retryApplies(stored: "a", current: "b", deadline: now.addingTimeInterval(60), now: now))
        XCTAssertFalse(CacheIdentity.retryApplies(stored: nil, current: "a", deadline: now.addingTimeInterval(60), now: now))
        XCTAssertTrue(CacheIdentity.cacheIsFresh(stored: "a", current: "a", fetchedAt: now.addingTimeInterval(-299), now: now))
        XCTAssertFalse(CacheIdentity.cacheIsFresh(stored: "a", current: "a", fetchedAt: now.addingTimeInterval(-300), now: now))
        XCTAssertFalse(CacheIdentity.cacheIsFresh(stored: "a", current: "a", fetchedAt: now.addingTimeInterval(1), now: now))
        XCTAssertFalse(CacheIdentity.cacheIsFresh(stored: "a", current: "b", fetchedAt: now, now: now))
    }
}
