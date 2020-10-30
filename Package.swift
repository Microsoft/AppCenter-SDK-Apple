// swift-tools-version:5.0

// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import PackageDescription

let package = Package(
    name: "App Center",
    platforms: [
        .iOS(.v9),
        .macOS(.v10_10),
        .tvOS(.v11)
    ],
    products: [
        .library(
            name: "AppCenterAnalytics",
            type: .static,
            targets: ["AppCenterAnalytics"]),
        .library(
            name: "AppCenterCrashes",
            type: .static,
            targets: ["AppCenterCrashes"])
    ],
    dependencies: [
        // TODO replace commit hash to released version before release.
        .package(url: "https://github.com/microsoft/plcrashreporter.git", .revision("54e06bbedb47337115779837668dc4e96f6cabeb")),
    ],
    targets: [
        .target(
            name: "AppCenter",
            path: "AppCenter/AppCenter",
            exclude: ["Support"],
            cSettings: [
                .define("APP_CENTER_C_VERSION", to:"\"4.0.0\""),
                .define("APP_CENTER_C_BUILD", to:"\"1\""),
                .headerSearchPath("**"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("sqlite3"),
                .linkedFramework("Foundation"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreTelephony", .when(platforms: [.iOS, .macOS])),
            ]
        ),
        .target(
            name: "AppCenterAnalytics",
            dependencies: ["AppCenter"],
            path: "AppCenterAnalytics/AppCenterAnalytics",
            exclude: ["Support"],
            cSettings: [
                .headerSearchPath("**"),
                .headerSearchPath("../../AppCenter/AppCenter/**"),
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "AppCenterCrashes",
            dependencies: ["AppCenter", "CrashReporter"],
            path: "AppCenterCrashes/AppCenterCrashes",
            exclude: ["Support"],
            cSettings: [
                .headerSearchPath("**"),
                .headerSearchPath("../../AppCenter/AppCenter/**"),
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        )
    ]
)
