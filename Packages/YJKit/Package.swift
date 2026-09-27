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
        .library(name: "MonitoringCore", targets: ["MonitoringCore"]),
    ],
    dependencies: [
        // Crashlytics 만 쓴다. 다른 Firebase 프로덕트는 Phase 2.
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
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
        .target(
            name: "MonitoringCore",
            dependencies: [
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ],
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
        .testTarget(
            name: "MonitoringCoreTests",
            dependencies: ["MonitoringCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
