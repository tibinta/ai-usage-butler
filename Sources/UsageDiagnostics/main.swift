import Foundation
import UsageCore

@main struct Diagnostics {
    static func main() async throws {
        let providers = await UsageReader.read()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(providers)
        print(String(decoding: data, as: UTF8.self))
    }
}
