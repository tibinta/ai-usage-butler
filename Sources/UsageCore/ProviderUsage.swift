import Foundation

public struct ProviderUsage: Codable {
    public let name: String
    public let weekly: UsageWindow?
    public let session: UsageWindow?
    public let fetchedAt: Date?
    public let message: String?
    public init(name: String, weekly: UsageWindow?, session: UsageWindow?, fetchedAt: Date?, message: String?) {
        self.name = name; self.weekly = weekly; self.session = session; self.fetchedAt = fetchedAt; self.message = message
    }
}

