import Foundation

public struct UsageWindow: Codable, Equatable {
    public let remaining: Double
    public let reset: Date
    public let duration: TimeInterval
    public init(remaining: Double, reset: Date, duration: TimeInterval) {
        self.remaining = remaining
        self.reset = reset
        self.duration = duration
    }
}

public struct Pacing: Equatable {
    public let wake: Date
    public let bedtime: Date
    public let target: Double?
    public let allowance: Double?
    public let paceDifference: Double?
    public let resetsBeforeWake: Bool

    public static func calculate(window: UsageWindow, now: Date, calendar: Calendar = .current) -> Pacing? {
        guard window.duration > 0, window.remaining.isFinite, (0...100).contains(window.remaining), window.reset > now else { return nil }
        let todayWake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)!
        let wake = now < todayWake ? todayWake : calendar.date(byAdding: .day, value: 1, to: todayWake)!
        let bedtimeDay = calendar.date(byAdding: .day, value: -1, to: wake)!
        let bedtime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: bedtimeDay)!
        let expectedNow = 100 * min(1, max(0, window.reset.timeIntervalSince(now) / window.duration))
        let resetsBeforeWake = window.reset <= wake
        let target: Double? = resetsBeforeWake ? (window.reset >= bedtime ? 5 : nil) : 100 * min(1, max(0, window.reset.timeIntervalSince(wake) / window.duration))
        return Pacing(wake: wake, bedtime: bedtime, target: target,
                      allowance: target.map { window.remaining - $0 },
                      paceDifference: window.remaining - expectedNow,
                      resetsBeforeWake: resetsBeforeWake)
    }
}
