// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zudio",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Zudio",
            path: "Sources/Zudio",
            exclude: ["Info.plist"],
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
