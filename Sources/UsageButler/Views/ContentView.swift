import SwiftUI
import AppKit
import UsageCore

private enum Style {
    static let ivory = Color(red: 250/255, green: 249/255, blue: 246/255)
    static let ink = Color(red: 14/255, green: 20/255, blue: 25/255)
    static let line = Color(red: 216/255, green: 204/255, blue: 179/255)
    static func serif(_ size: CGFloat) -> Font { .custom("LibreBaskerville-Regular", size: size) }
    static func color(_ name: String) -> Color {
        switch name { case "green": return Color(red: 0.10, green: 0.38, blue: 0.25)
        case "red": return Color(red: 0.66, green: 0.16, blue: 0.15)
        default: return Color(red: 0.55, green: 0.35, blue: 0.04) }
    }
}

struct ContentView: View {
    @ObservedObject var store: UsageStore
    var body: some View {
        let now = Date()
        let active = DecisionPolicy.activeProvider(store.providers, now: now)
        let allSpent = DecisionPolicy.allSpent(store.providers, now: now)
        return VStack(alignment: .leading, spacing: 12) {
            if let active {
                let guidance = DecisionPolicy.guidance(active, now: now)
                ProviderRow(
                    provider: active,
                    headline: Banter.line(color: guidance.color, pause: guidance.text == "Pause until 7 am", now: now),
                    guidance: guidance.text,
                    now: now,
                    connectClaude: { store.connectClaude() }
                )
            } else if allSpent {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Banter.line(color: "red", now: now)).font(Style.serif(17)).lineLimit(1).foregroundStyle(Style.color("red"))
                    Text("Wait for reset").font(Style.serif(14)).foregroundStyle(Style.color("red"))
                }
            } else {
                Text(DecisionPolicy.menuTitle(store.providers, now: now)).font(Style.serif(17)).foregroundStyle(Style.color(DecisionPolicy.color(store.providers, now: now)))
            }
            ForEach(store.providers.filter { $0.name != active?.name }, id: \.name) { provider in
                InactiveProvider(provider: provider, connectClaude: { store.connectClaude() })
            }
            Rectangle().fill(Style.line).frame(height: 1)
            HStack {
                Button { store.refresh() } label: { Label(store.refreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise") }.disabled(store.refreshing)
                Spacer()
                Button(store.alertsEnabled ? "Alerts on" : "Enable alerts") { store.enableAlerts() }.disabled(store.alertsEnabled)
                Toggle("Login", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) })).toggleStyle(.checkbox).padding(.leading, 8)
                Button("Quit") { NSApp.terminate(nil) }.padding(.leading, 8)
            }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Style.ink)
            if let message = store.alertMessage ?? store.loginMessage { Text(message).font(.system(size: 10)).foregroundStyle(.secondary) }
        }.padding(20).frame(width: 680).background(Style.ivory).foregroundStyle(Style.ink)
    }
}

private func amount(_ value: Double) -> String { String(format: "%.1f%%", value) }
private func targetAmount(_ value: Double) -> String { amount(DecisionPolicy.displayedTarget(value)) }

private struct ProviderRow: View {
    let provider: ProviderUsage
    let headline: String
    let guidance: String
    let now: Date
    let connectClaude: () -> Void
    @State private var details = false
    private var pacing: Pacing? { DecisionPolicy.pacing(provider, now: now) }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(headline).font(Style.serif(17)).lineLimit(1).foregroundStyle(Style.color(DecisionPolicy.color([provider], now: now)))
            HStack {
                Text(guidance).font(Style.serif(14))
                Spacer()
                Text(provider.name).font(Style.serif(14))
            }.foregroundStyle(Style.color(DecisionPolicy.color([provider], now: now)))
            if let weekly = provider.weekly, let p = pacing {
                Text("Now: \(amount(weekly.remaining)) left")
                Text("Should have now: \(amount(weekly.remaining - (p.paceDifference ?? 0))) left")
                Text("Current pace: \(DecisionPolicy.status(provider, now: now).rawValue)").font(.system(size: 10)).foregroundStyle(.secondary)
                if let target = p.target {
                    Text(p.resetsBeforeWake ? "At 10 pm: keep \(targetAmount(target)) until reset" : "At 10 pm: keep \(targetAmount(target)) left")
                } else { Text("Resets before 10 pm · next limit unknown") }
                if provider.session != nil { Text("Session limit may constrain use.").font(.system(size: 10)).foregroundStyle(.secondary) }
            } else { Text("Waiting for a fresh reading.").foregroundStyle(.secondary) }
            DisclosureGroup("Details", isExpanded: $details) {
                VStack(alignment: .leading, spacing: 5) {
                    if let message = provider.message { Text(message) }
                    if provider.name == "Claude", provider.fetchedAt == nil { Button("Connect Claude") { connectClaude() } }
                    if let fetched = provider.fetchedAt { Text("Updated \(fetched.formatted(date: .abbreviated, time: .shortened))") }
                    row(provider.weekly, name: "Weekly")
                    row(provider.session, name: "Session")
                    Text("10 pm target accounts for 7 am. On overnight reset nights, keep 5% until reset.")
                }.padding(.top, 6).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }.font(Style.serif(13))
    }
    @ViewBuilder private func row(_ window: UsageWindow?, name: String) -> some View {
        if let window {
            Text(window.reset <= now ? "\(name): reset passed · refresh needed" : "\(name): \(amount(window.remaining)) left · resets \(window.reset.formatted(date: .abbreviated, time: .shortened))")
        } else if name == "Session" && provider.name == "Codex" && provider.weekly != nil { Text("No session limit reported") }
        else { Text("\(name): unavailable") }
    }
}

private struct InactiveProvider: View {
    let provider: ProviderUsage
    let connectClaude: () -> Void
    @State private var details = false
    var body: some View {
        DisclosureGroup(isExpanded: $details) {
            VStack(alignment: .leading, spacing: 5) {
                if let message = provider.message { Text(message) }
                if provider.name == "Claude", provider.fetchedAt == nil { Button("Connect Claude") { connectClaude() } }
                if let session = provider.session {
                    Text(session.reset <= Date() ? "Session reset passed · awaiting updated usage" :
                         "Session: \(amount(session.remaining)) left · resets \(session.reset.formatted(date: .abbreviated, time: .shortened))")
                }
            }.font(.system(size: 10)).padding(.top, 5).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            if let weekly = provider.weekly, weekly.remaining <= 1, weekly.reset > Date(), provider.fetchedAt.map({ Date().timeIntervalSince($0) <= 900 }) == true {
                Text("\(provider.name) spent · resets \(weekly.reset.formatted(date: .abbreviated, time: .shortened))")
            } else if let weekly = provider.weekly, weekly.reset > Date(), provider.fetchedAt.map({ Date().timeIntervalSince($0) >= 0 && Date().timeIntervalSince($0) <= 900 }) == true {
                Text("\(provider.name): \(amount(weekly.remaining)) left · resets \(weekly.reset.formatted(date: .abbreviated, time: .shortened))")
            } else { Text("\(provider.name) · details") }
        }.font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
