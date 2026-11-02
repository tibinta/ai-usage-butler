import Foundation
import Security
import LocalAuthentication
import CryptoKit

public enum UsageReader {
    public static func read() async -> [ProviderUsage] {
        async let codex = readCodex()
        async let claude = readClaude()
        return await [codex, claude]
    }

    public static func readCodex() async -> ProviderUsage {
        await Task.detached {
            let process = Process(), output = Pipe(), input = Pipe()
            let codexPaths = [NSHomeDirectory() + "/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            guard let codexPath = codexPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                return ProviderUsage(name: "Codex", weekly: nil, session: nil, fetchedAt: nil, message: "Could not read Codex usage. Check that Codex is signed in.")
            }
            process.executableURL = URL(fileURLWithPath: codexPath)
            process.arguments = ["app-server"]
            process.standardOutput = output; process.standardInput = input; process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 8, execute: timeout)
                defer { timeout.cancel(); if process.isRunning { process.terminate() } }
                func send(_ object: [String: Any]) throws {
                    var data = try JSONSerialization.data(withJSONObject: object); data.append(10)
                    try input.fileHandleForWriting.write(contentsOf: data)
                }
                func response(_ id: Int) -> [String: Any]? {
                    var line = Data()
                    while true {
                        let data = output.fileHandleForReading.readData(ofLength: 1)
                        if data.isEmpty { return nil }
                        if data[0] == 10 {
                            defer { line.removeAll(keepingCapacity: true) }
                            if let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any], json["id"] as? Int == id { return json }
                        } else { line.append(data) }
                    }
                }
                try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "usage_butler", "version": "1.0"]]])
                guard response(1)?["result"] != nil else { throw ReadError.unavailable }
                try send(["method": "initialized"])
                try send(["id": 2, "method": "account/rateLimits/read"])
                guard let result = response(2)?["result"] as? [String: Any], let limits = result["rateLimits"] as? [String: Any] else { throw ReadError.unavailable }
                let windows = [limits["primary"], limits["secondary"]].compactMap { $0 as? [String: Any] }.compactMap { item -> UsageWindow? in
                    guard let used = item["usedPercent"] as? Double, let minutes = item["windowDurationMins"] as? Double, let epoch = item["resetsAt"] as? Double, (0...100).contains(used), minutes > 0 else { return nil }
                    return UsageWindow(remaining: 100 - used, reset: Date(timeIntervalSince1970: epoch), duration: minutes * 60)
                }
                let weekly = windows.first { $0.duration >= 6 * 86400 }
                let session = windows.first { $0.duration < 6 * 86400 }
                return ProviderUsage(name: "Codex", weekly: weekly, session: session, fetchedAt: Date(), message: nil)
            } catch { return ProviderUsage(name: "Codex", weekly: nil, session: nil, fetchedAt: nil, message: "Could not read Codex usage. Check that Codex is signed in.") }
        }.value
    }

    public static func readClaude(allowInteraction: Bool = false) async -> ProviderUsage {
        let domain = "agency.lpv.UsageButler"
        let defaults = Bundle.main.bundleIdentifier == domain ? UserDefaults.standard : (UserDefaults(suiteName: domain) ?? .standard)
        let context = LAContext()
        context.interactionNotAllowed = !allowInteraction
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Claude Code-credentials", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne, kSecUseAuthenticationContext as String: context]
        var result: CFTypeRef?
        // Legacy macOS Keychain items ignore LAContext's no-UI flag.
        let status: OSStatus = {
            var previous: DarwinBoolean = true
            guard SecKeychainGetUserInteractionAllowed(&previous) == errSecSuccess,
                  SecKeychainSetUserInteractionAllowed(allowInteraction) == errSecSuccess else { return errSecInteractionNotAllowed }
            defer { SecKeychainSetUserInteractionAllowed(previous.boolValue) }
            return SecItemCopyMatching(query as CFDictionary, &result)
        }()
        guard status == errSecSuccess, let data = result as? Data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any], let token = oauth["accessToken"] as? String else {
            return ProviderUsage(name: "Claude", weekly: nil, session: nil, fetchedAt: nil, message: "Claude Keychain access is unavailable. Use Connect Claude to authorize access.")
        }
        let fingerprint = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        func cached(_ message: String) -> ProviderUsage {
            guard CacheIdentity.matches(stored: defaults.string(forKey: "claudeIdentity"), current: fingerprint),
                  let data = defaults.data(forKey: "claudeUsage"), let old = try? JSONDecoder().decode(ProviderUsage.self, from: data) else {
                return ProviderUsage(name: "Claude", weekly: nil, session: nil, fetchedAt: nil, message: message)
            }
            return ProviderUsage(name: old.name, weekly: old.weekly, session: old.session, fetchedAt: old.fetchedAt, message: message)
        }
        if let data = defaults.data(forKey: "claudeUsage"), let old = try? JSONDecoder().decode(ProviderUsage.self, from: data),
           CacheIdentity.cacheIsFresh(stored: defaults.string(forKey: "claudeIdentity"), current: fingerprint, fetchedAt: old.fetchedAt, now: Date()) {
            return old
        }
        if defaults.string(forKey: "claudeRetryIdentity") == nil {
            defaults.removeObject(forKey: "claudeRetryAfter")
        }
        if let deadline = defaults.object(forKey: "claudeRetryAfter") as? Date,
           CacheIdentity.retryApplies(stored: defaults.string(forKey: "claudeRetryIdentity"), current: fingerprint, deadline: deadline, now: Date()) {
            return cached("Claude is rate limiting checks. Retry after \(deadline.formatted(date: .omitted, time: .shortened)).")
        }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ReadError.unavailable }
            guard http.statusCode == 200 else {
                let message: String
                switch http.statusCode {
                case 401, 403:
                    defaults.removeObject(forKey: "claudeUsage")
                    defaults.removeObject(forKey: "claudeIdentity")
                    return ProviderUsage(name: "Claude", weekly: nil, session: nil, fetchedAt: nil, message: "Sign-in expired. Open Claude Code to renew it.")
                case 429:
                    let header = http.value(forHTTPHeaderField: "Retry-After")
                    let seconds = header.flatMap(TimeInterval.init)
                    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                    let deadline = seconds.map { Date().addingTimeInterval(max(0, $0)) } ?? header.flatMap { formatter.date(from: $0) } ?? Date().addingTimeInterval(900)
                    defaults.set(max(deadline, Date().addingTimeInterval(60)), forKey: "claudeRetryAfter")
                    defaults.set(fingerprint, forKey: "claudeRetryIdentity")
                    message = "Claude is rate limiting usage checks. Try again later."
                default: message = "Claude usage unavailable (HTTP \(http.statusCode))."
                }
                return cached(message)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ReadError.unavailable }
            func window(_ key: String, duration: TimeInterval) -> UsageWindow? {
                guard let item = json[key] as? [String: Any], let used = item["utilization"] as? Double, (0...100).contains(used), let text = item["resets_at"] as? String else { return nil }
                let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let reset = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) else { return nil }
                return UsageWindow(remaining: 100 - used, reset: reset, duration: duration)
            }
            let additional = json.contains { key, value in key.hasPrefix("seven_day_") && (value as? [String: Any])?["utilization"] is NSNumber }
            let value = ProviderUsage(name: "Claude", weekly: window("seven_day", duration: 7 * 86400), session: window("five_hour", duration: 5 * 3600), fetchedAt: Date(), message: additional ? "Additional model-specific limits may apply." : nil)
            if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "claudeUsage"); defaults.set(fingerprint, forKey: "claudeIdentity") }
            defaults.removeObject(forKey: "claudeRetryAfter")
            defaults.removeObject(forKey: "claudeRetryIdentity")
            return value
        } catch { return cached("Could not reach Claude usage. Refresh when connected.") }
    }
    private enum ReadError: Error { case unavailable }
}
