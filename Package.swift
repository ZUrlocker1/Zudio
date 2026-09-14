// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zudio",
    platforms: [.macOS(.v14), .iOS(.v16)],
    targets: [
        .executableTarget(
            name: "Zudio",
            path: "Sources/Zudio",
            // Xcode-only build inputs — not sources SPM should try to handle.
            exclude: ["Info.plist", "iOS-Info.plist", "ZudioiOS.entitlements"],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ZudioTests",
            dependencies: ["Zudio"],
            path: "Tests/ZudioTests"
        )
    ]
)
