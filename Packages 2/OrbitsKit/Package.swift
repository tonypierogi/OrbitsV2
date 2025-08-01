// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrbitsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OrbitsKit",
            targets: ["OrbitsKit"]),
    ],
    dependencies: [
        // Future server-side dependencies can go here
    ],
    targets: [
        .target(
            name: "OrbitsKit",
            dependencies: []),
        .testTarget(
            name: "OrbitsKitTests",
            dependencies: ["OrbitsKit"]),
    ]
)