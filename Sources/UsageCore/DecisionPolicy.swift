import Foundation

public enum PaceStatus: String {
    case useMore = "use more", onTrack = "on track", slowDown = "slow down"
    case protectNight = "protect night allowance", exhausted = "wait for reset", checking = "checking"
}

public enum DecisionPolicy {
    public static func pacing(_ provider: ProviderUsage, now: Date, calendar: Calendar = .current) -> Pacing? {
        guard let fetched = provider.fetchedAt, now.timeIntervalSince(fetched) >= 0, now.timeIntervalSince(fetched) <= 900,
              let weekly = provider.weekly else { return nil }
        return Pacing.calculate(window: weekly, now: now, calendar: calendar)
    }
    public static func status(_ provider: ProviderUsage, now: Date, calendar: Calendar = .current) -> PaceStatus {
        guard let p = pacing(provider, now: now, calendar: calendar), let weekly = provider.weekly else { return .checking }
        if weekly.remaining <= 0 { return .exhausted }
        if let session = provider.session {
            if session.reset <= now { return .checking }
            if session.remaining <= 0 { return .exhausted }
        } else if provider.name != "Codex" { return .checking }
        if p.resetsBeforeWake && p.target == 5 && weekly.remaining <= 5 { return .protectNight }
        guard let delta = p.paceDifference else { return .checking }
        if delta > 3 { return .useMore }
        if delta < -3 { return .slowDown }
        return .onTrack
    }
    public static func activeProvider(_ providers: [ProviderUsage], now: Date, calendar: Calendar = .current) -> ProviderUsage? {
        let usable = ["Claude", "Codex"].compactMap { name -> ProviderUsage? in
            guard let p = providers.first(where: { $0.name == name }), let weekly = p.weekly,
                  pacing(p, now: now, calendar: calendar) != nil, weekly.remaining > 1 else { return nil }
            if let session = p.session { guard session.reset > now, session.remaining > 0 else { return nil } }
            else if name != "Codex" { return nil }
            return p
        }
        let expiring = usable.filter { p in
            guard let plan = pacing(p, now: now, calendar: calendar), let reset = p.weekly?.reset else { return false }
            return plan.target == nil && reset < plan.bedtime
        }.sorted { $0.weekly!.reset < $1.weekly!.reset }
        return expiring.first ?? usable.first { p in
            guard let plan = pacing(p, now: now, calendar: calendar), let allowance = plan.allowance else { return false }
            return allowance > 0
        } ?? usable.first
    }
    public static func displayedTarget(_ target: Double) -> Double { ceil(target * 10) / 10 }
    public static func guidance(_ provider: ProviderUsage, now: Date, calendar: Calendar = .current) -> (text: String, color: String) {
        guard let p = pacing(provider, now: now, calendar: calendar) else { return ("Checking usage", "amber") }
        if now >= p.bedtime { return ("Pause until 7 am", "amber") }
        if p.target == nil, let weekly = provider.weekly {
            let value = String(format: "%.1f", floor(weekly.remaining * 10) / 10)
            return ("Up to \(value)% before reset", weekly.remaining <= 2 ? "amber" : "green")
        }
        guard let allowance = p.allowance else { return ("Checking usage", "amber") }
        if allowance <= 0 { return ("Slow down", "red") }
        let safeAmount = floor(allowance * 10) / 10
        let value = String(format: "%.1f", safeAmount)
        return allowance <= 2 ? ("\(value)% left for today", "amber") : ("Up to \(value)% more today", "green")
    }
    public static func allSpent(_ providers: [ProviderUsage], now: Date, calendar: Calendar = .current) -> Bool {
        ["Claude", "Codex"].allSatisfy { name in
            guard let p = providers.first(where: { $0.name == name }), let weekly = p.weekly,
                  pacing(p, now: now, calendar: calendar) != nil else { return false }
            if weekly.remaining <= 1 { return true }
            guard let session = p.session, session.reset > now else { return false }
            return session.remaining <= 0
        }
    }
    public static func menuTitle(_ providers: [ProviderUsage], now: Date, calendar: Calendar = .current) -> String {
        guard let p = activeProvider(providers, now: now, calendar: calendar) else { return allSpent(providers, now: now, calendar: calendar) ? "Wait for reset" : "Checking available usage" }
        return "\(p.name): \(guidance(p, now: now, calendar: calendar).text.lowercased())"
    }
    public static func color(_ providers: [ProviderUsage], now: Date) -> String {
        guard let p = activeProvider(providers, now: now) else { return allSpent(providers, now: now) ? "red" : "amber" }
        return guidance(p, now: now).color
    }
}
