// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sillage",
    platforms: [.macOS("14.2")],
    products: [.executable(name: "Sillage", targets: ["SillageApp"])],
    targets: [
        .target(name: "CRealtime", linkerSettings: [.linkedFramework("CoreAudio")]),
        .target(name: "AudioAnalysis", dependencies: ["CRealtime"], linkerSettings: [.linkedFramework("Accelerate")]),
        .target(name: "SystemCapture", dependencies: ["CRealtime"], linkerSettings: [.linkedFramework("CoreAudio")]),
        .executableTarget(name: "SillageApp", dependencies: ["AudioAnalysis", "SystemCapture", "CRealtime"]),
        .testTarget(name: "AudioAnalysisTests", dependencies: ["AudioAnalysis", "CRealtime"])
    ]
)
