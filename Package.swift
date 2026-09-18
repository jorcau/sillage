// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sillage",
    defaultLocalization: "en",
    platforms: [.macOS("14.2")],
    products: [.executable(name: "Sillage", targets: ["SillageApp"])],
    targets: [
        .target(name: "AppLocalization", resources: [.process("Resources")]),
        .target(name: "CRealtime", linkerSettings: [.linkedFramework("CoreAudio")]),
        .target(name: "AudioAnalysis", dependencies: ["CRealtime"], linkerSettings: [.linkedFramework("Accelerate")]),
        .target(name: "SystemCapture", dependencies: ["CRealtime"], linkerSettings: [.linkedFramework("CoreAudio")]),
        .executableTarget(name: "SillageApp", dependencies: ["AudioAnalysis", "SystemCapture", "CRealtime", "AppLocalization"]),
        .testTarget(name: "AudioAnalysisTests", dependencies: ["AudioAnalysis", "CRealtime"]),
        .testTarget(name: "AppLocalizationTests", dependencies: ["AppLocalization"])
    ]
)
