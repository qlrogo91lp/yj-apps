// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RalliKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
        .library(name: "ConnectivityCore", targets: ["ConnectivityCore"]),
        .library(name: "PersistenceCore", targets: ["PersistenceCore"]),
    ],
    targets: [
        .target(
            name: "WorkoutCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "ConnectivityCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "PersistenceCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WorkoutCoreTests",
            dependencies: ["WorkoutCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ConnectivityCoreTests",
            dependencies: ["ConnectivityCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PersistenceCoreTests",
            dependencies: ["PersistenceCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
