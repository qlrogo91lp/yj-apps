// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YJKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
        .library(name: "WorkoutUI", targets: ["WorkoutUI"]),
        .library(name: "ConnectivityCore", targets: ["ConnectivityCore"]),
        .library(name: "PersistenceCore", targets: ["PersistenceCore"]),
        .library(name: "WorkoutShareUI", targets: ["WorkoutShareUI"]),
    ],
    targets: [
        .target(
            name: "WorkoutCore",
            dependencies: ["ConnectivityCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "WorkoutUI",
            dependencies: ["WorkoutCore"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "WorkoutShareUI",
            dependencies: ["WorkoutCore"],
            resources: [.process("Resources")],
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
        .testTarget(
            name: "WorkoutShareUITests",
            dependencies: ["WorkoutShareUI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
