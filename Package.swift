// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Clippy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClippyCore", targets: ["ClippyCore"]),
        .executable(name: "Clippy", targets: ["ClippyApp"])
    ],
    targets: [
        .target(
            name: "ClippyCore",
            path: "Sources/ClippyCore"
        ),
        .executableTarget(
            name: "ClippyApp",
            dependencies: ["ClippyCore"],
            path: "Sources/ClippyApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ClippyCoreTests",
            dependencies: ["ClippyCore"],
            path: "Tests/ClippyCoreTests"
        )
    ]
)
