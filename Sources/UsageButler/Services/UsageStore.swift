import Foundation
import UsageCore
import ServiceManagement
import UserNotifications

@MainActor final class UsageStore: ObservableObject {
    @Published var providers = [ProviderUsage(name: "Codex", weekly: nil, session: nil, fetchedAt: nil, message: "Not loaded"), ProviderUsage(name: "Claude", weekly: nil, session: nil, fetchedAt: nil, message: "Not loaded")]
    @Published var refreshing = false
    @Published var loginMessage: String?
    @Published var alertMessage: String?
    @Published var alertsEnabled = false
    private var timer: Timer?
    private var lastRefresh = Date.distantPast
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                if Date().timeIntervalSince(self.lastRefresh) >= 300 { self.refresh() }
            }
        }
        refresh()
    }
    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = nil
            objectWillChange.send()
        } catch { loginMessage = "Could not change login setting: \(error.localizedDescription)" }
    }

    func enableAlerts() {
        Task {
            do {
                alertsEnabled = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                alertMessage = alertsEnabled ? nil : "Alerts are off in System Settings."
                if alertsEnabled { await notifyIfNeeded() }
            } catch { alertMessage = "Could not enable alerts: \(error.localizedDescription)" }
        }
    }
    private func notifyIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        alertsEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        guard alertsEnabled else { return }
        let defaults = UserDefaults.standard
        var sent = Set(defaults.stringArray(forKey: "sentAlerts") ?? [])
        for alert in AlertPolicy.alerts(for: providers, now: Date(), sent: sent) {
            let content = UNMutableNotificationContent(); content.title = alert.title; content.body = alert.body; content.sound = .default
            do {
                try await center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: nil))
                sent.insert(alert.id)
            } catch { alertMessage = "Notifications could not be delivered. Check macOS notification settings." }
        }
        defaults.set(Array(sent.sorted().suffix(200)), forKey: "sentAlerts")
    }

    private func update(_ provider: ProviderUsage) {
        if let index = providers.firstIndex(where: { $0.name == provider.name }) { providers[index] = provider }
    }
    func connectClaude() {
        guard !refreshing else { return }
        refreshing = true
        Task {
            update(await UsageReader.readClaude(allowInteraction: true))
            await notifyIfNeeded()
            refreshing = false
        }
    }
    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        lastRefresh = Date()
        Task {
            await withTaskGroup(of: ProviderUsage.self) { group in
                group.addTask { await UsageReader.readCodex() }
                group.addTask { await UsageReader.readClaude() }
                for await provider in group { update(provider) }
            }
            await notifyIfNeeded()
            refreshing = false
        }
    }
}
