import XCTest
@testable import UsageCore

final class PacingTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }
    func date(_ text: String) -> Date {
        let f = DateFormatter(); f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: text)!
    }
    func testTargetAndNegativeAllowance() {
        let p = Pacing.calculate(window: .init(remaining: 10, reset: date("2026-11-07 12:00"), duration: 7 * 86400), now: date("2026-10-31 12:00"), calendar: calendar)!
        XCTAssertEqual(p.wake, date("2026-11-01 07:00"))
        XCTAssertLessThan(p.allowance!, 0)
        XCTAssertEqual(p.bedtime, date("2026-10-31 22:00"))
    }
    func testOvernightResetDoesNotPromiseNewAllowance() {
        let p = Pacing.calculate(window: .init(remaining: 0, reset: date("2026-11-01 04:00"), duration: 7 * 86400), now: date("2026-10-31 20:00"), calendar: calendar)!
        XCTAssertTrue(p.resetsBeforeWake); XCTAssertEqual(p.target, 5); XCTAssertEqual(p.allowance, -5)
        for reset in ["2026-10-31 22:00", "2026-11-01 00:00", "2026-11-01 07:00"] {
            let result = Pacing.calculate(window: .init(remaining: 10, reset: date(reset), duration: 7 * 86400), now: date("2026-10-31 20:00"), calendar: calendar)!
            XCTAssertEqual(result.target, 5); XCTAssertEqual(result.allowance, 5)
        }
        let beforeBed = Pacing.calculate(window: .init(remaining: 10, reset: date("2026-10-31 21:00"), duration: 7 * 86400), now: date("2026-10-31 20:00"), calendar: calendar)!
        XCTAssertNil(beforeBed.target); XCTAssertNil(beforeBed.allowance)
    }
    func testBeforeWakeAndDSTCalendar() {
        let p = Pacing.calculate(window: .init(remaining: 50, reset: date("2026-10-30 12:00"), duration: 7 * 86400), now: date("2026-10-25 01:00"), calendar: calendar)!
        XCTAssertEqual(p.wake, date("2026-10-25 07:00")); XCTAssertEqual(p.bedtime, date("2026-10-24 22:00"))
    }
    func testExpiredAndInvalidAreUnavailable() {
        XCTAssertNil(Pacing.calculate(window: .init(remaining: 0, reset: date("2026-10-31 12:00"), duration: 1), now: date("2026-10-31 12:00"), calendar: calendar))
        XCTAssertNil(Pacing.calculate(window: .init(remaining: 101, reset: date("2026-11-01 12:00"), duration: 1), now: date("2026-10-31 12:00"), calendar: calendar))
    }
}
