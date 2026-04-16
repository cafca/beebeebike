// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ferrostar_flutter",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "ferrostar-flutter", targets: ["ferrostar_flutter"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "ferrostar", url: "https://github.com/stadiamaps/ferrostar", from: "0.49.0"),
    ],
    targets: [
        .target(
            name: "ferrostar_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "FerrostarCore", package: "ferrostar"),
            ],
            path: "Sources/ferrostar_flutter"
        ),
    ]
)
