// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OrtschaftiOS",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "OrtschaftiOS",
            targets: ["OrtschaftiOS"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OrtschaftiOS",
            path: "Sources/OrtschaftiOS"
        ),
        .testTarget(
            name: "OrtschaftiOSTests",
            dependencies: ["OrtschaftiOS"],
            path: "Tests/OrtschaftiOSTests"
        )
    ]
)
