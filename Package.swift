// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsageButler",
    platforms: [.macOS(.v14)],
    products: [.library(name: "UsageCore", targets: ["UsageCore"]), .executable(name: "UsageButler", targets: ["UsageButler"]), .executable(name: "UsageDiagnostics", targets: ["UsageDiagnostics"])],
    targets: [.target(name: "UsageCore"), .executableTarget(name: "UsageButler", dependencies: ["UsageCore"]), .executableTarget(name: "UsageDiagnostics", dependencies: ["UsageCore"]), .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"])]
)
