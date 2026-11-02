import XCTest
@testable import UsageCore

final class DecisionPolicyTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-10-31T12:00:00Z")!
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func provider(_ name: String, _ remaining: Double, session: Double? = nil, reset: Date? = nil, fetched: Date? = nil) -> ProviderUsage {
        ProviderUsage(name: name, weekly: UsageWindow(remaining: remaining, reset: reset ?? now.addingTimeInterval(4 * 86400), duration: 7 * 86400), session: session.map { UsageWindow(remaining: $0, reset: now.addingTimeInterval(3600), duration: 18000) }, fetchedAt: fetched ?? now, message: nil)
    }
    func testStatusIsBasedOnCurrentPace() {
        XCTAssertEqual(DecisionPolicy.status(provider("Codex", 90), now: now, calendar: calendar), .useMore)
        XCTAssertEqual(DecisionPolicy.status(provider("Codex", 30), now: now, calendar: calendar), .slowDown)
        XCTAssertEqual(DecisionPolicy.status(provider("Codex", 57.14), now: now, calendar: calendar), .onTrack)
        XCTAssertEqual(DecisionPolicy.status(provider("Codex", 90, session: 0), now: now, calendar: calendar), .exhausted)
        XCTAssertEqual(DecisionPolicy.status(provider("Codex", 90, fetched: now.addingTimeInterval(-901)), now: now, calendar: calendar), .checking)
    }
    func testSpentClaudeSelectsCodex() {
        let providers = [provider("Codex", 90), provider("Claude", 1, session: 90)]
        XCTAssertEqual(DecisionPolicy.activeProvider(providers, now: now, calendar: calendar)?.name, "Codex")
        XCTAssertTrue(DecisionPolicy.menuTitle(providers, now: now, calendar: calendar).hasPrefix("Codex: up to"))
        let both = [provider("Codex", 90), provider("Claude", 30, session: 90)]
        XCTAssertEqual(DecisionPolicy.activeProvider(both, now: now, calendar: calendar)?.name, "Codex")
    }
    func testHeadroomColorsAndNightPause() {
        let base = provider("Codex", 90)
        let target = DecisionPolicy.pacing(base, now: now, calendar: calendar)!.target!
        let green = provider("Codex", target + 10.3)
        let amber = provider("Codex", target + 1.5)
        let red = provider("Codex", target - 1)
        XCTAssertEqual(DecisionPolicy.guidance(green, now: now, calendar: calendar).color, "green")
        XCTAssertEqual(DecisionPolicy.guidance(amber, now: now, calendar: calendar).color, "amber")
        XCTAssertEqual(DecisionPolicy.guidance(red, now: now, calendar: calendar).color, "red")
        let late = now.addingTimeInterval(11 * 3600)
        let updated = provider("Codex", 90, fetched: late)
        XCTAssertEqual(DecisionPolicy.guidance(updated, now: late, calendar: calendar).text, "Pause until 7 am")
    }
    func testExpiringWindowTakesPriorityAndAllSpentStops() {
        let soon = provider("Codex", 25, reset: now.addingTimeInterval(5 * 3600))
        let claude = provider("Claude", 90, session: 90)
        XCTAssertEqual(DecisionPolicy.activeProvider([soon, claude], now: now, calendar: calendar)?.name, "Codex")
        XCTAssertEqual(DecisionPolicy.guidance(soon, now: now, calendar: calendar).text, "Up to 25.0% before reset")
        let spent = [provider("Codex", 1), provider("Claude", 1, session: 90)]
        XCTAssertEqual(DecisionPolicy.menuTitle(spent, now: now, calendar: calendar), "Wait for reset")
        XCTAssertEqual(DecisionPolicy.displayedTarget(86.726), 86.8)
    }
    func testNightProtectOnlyOnOvernightReset() {
        let night = provider("Codex", 5, reset: now.addingTimeInterval(12 * 3600))
        XCTAssertEqual(DecisionPolicy.status(night, now: now, calendar: calendar), .protectNight)
        let beforeBed = provider("Codex", 5, reset: now.addingTimeInterval(8 * 3600))
        XCTAssertNotEqual(DecisionPolicy.status(beforeBed, now: now, calendar: calendar), .protectNight)
    }
}
