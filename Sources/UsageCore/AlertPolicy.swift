import Foundation

public enum CacheIdentity {
    public static func matches(stored: String?, current: String) -> Bool { stored != nil && stored == current }
    public static func cacheIsFresh(stored: String?, current: String, fetchedAt: Date?, resetAt: Date? = nil, now: Date) -> Bool {
        guard matches(stored: stored, current: current), let fetchedAt else { return false }
        if let resetAt, resetAt <= now { return false }
        let age = now.timeIntervalSince(fetchedAt)
        return age >= 0 && age < 300
    }
    public static func retryApplies(stored: String?, current: String, deadline: Date, now: Date) -> Bool {
        matches(stored: stored, current: current) && deadline > now
    }
}

public struct UsageAlert: Equatable {
    public let id: String
    public let title: String
    public let body: String
}

public enum AlertPolicy {
    private static func sessionHasRoom(_ provider: ProviderUsage, now: Date) -> Bool {
        guard let session = provider.session else { return provider.name == "Codex" }
        return session.reset > now && session.remaining > 20
    }
    public static func alerts(for providers: [ProviderUsage], now: Date, calendar: Calendar = .current, sent: Set<String> = []) -> [UsageAlert] {
        let day = calendar.startOfDay(for: now).timeIntervalSince1970
        let summary = DecisionPolicy.menuTitle(providers, now: now, calendar: calendar)
        var alerts: [UsageAlert] = []
        for provider in providers {
            guard let fetched = provider.fetchedAt, now.timeIntervalSince(fetched) >= 0, now.timeIntervalSince(fetched) <= 900 else { continue }
            for (kind, window) in [("weekly", provider.weekly), ("session", provider.session)] {
                guard let window, window.reset > now else { continue }
                let severity: String
                let advice: String
                let night = kind == "weekly" && DecisionPolicy.pacing(provider, now: now, calendar: calendar).map { $0.resetsBeforeWake && $0.target == 5 } == true
                if window.remaining <= 0 { severity = "exhausted"; advice = "This limit is exhausted. Save your handoff and wait for reset." }
                else if window.remaining <= 5 && night { severity = "night"; advice = "Protect the remaining night allowance until reset." }
                else if window.remaining <= 10 { severity = "wrap"; advice = "Save a checkpoint and prepare to wrap up." }
                else if window.remaining <= 20 { severity = "handoff"; advice = "Prepare a handoff before the limit runs low." }
                else { continue }
                let id = "\(provider.name)-\(kind)-\(Int(window.reset.timeIntervalSince1970))-\(severity)-\(Int(day))"
                if !sent.contains(id) { alerts.append(UsageAlert(id: id, title: "\(provider.name) \(kind) · \(String(format: "%.1f", window.remaining))% left", body: advice + " " + summary + ".")) }
            }
            guard let weekly = provider.weekly, weekly.reset > now,
                  weekly.remaining > 20, sessionHasRoom(provider, now: now), let pacing = DecisionPolicy.pacing(provider, now: now, calendar: calendar),
                  now < pacing.bedtime else { continue }
            let nearBed = pacing.bedtime.timeIntervalSince(now) <= 3 * 3600
            let nearReset = weekly.reset.timeIntervalSince(now) <= 3 * 3600
            let room = (pacing.allowance ?? pacing.paceDifference ?? 0) >= 10
            let recommended = DecisionPolicy.activeProvider(providers, now: now, calendar: calendar)?.name == provider.name && DecisionPolicy.guidance(provider, now: now, calendar: calendar).color == "green"
            if (nearBed || nearReset) && room && recommended {
                let id = "\(provider.name)-weekly-\(Int(weekly.reset.timeIntervalSince1970))-room-\(Int(day))"
                if !sent.contains(id) { alerts.append(UsageAlert(id: id, title: "Room left on \(provider.name)", body: "There is room before your bedtime target; usage can vary.") ) }
            }
        }
        return alerts
    }
}
