// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OrtschaftMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OrtschaftMac",
            targets: ["OrtschaftMac"]
        ),
    ],
    targets: [
        .target(
            name: "OrtschaftMacCore",
            dependencies: [],
            path: "Sources/OrtschaftMac"
        ),
        .executableTarget(
            name: "OrtschaftMac",
            dependencies: ["OrtschaftMacCore"],
            path: "Sources/Runner"
        ),
        .testTarget(
            name: "OrtschaftMacTests",
            dependencies: ["OrtschaftMacCore"],
            path: "Tests/OrtschaftMacTests"
        )
    ]
)
