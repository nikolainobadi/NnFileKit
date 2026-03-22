// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NnFileKit",
    products: [
        .library(
            name: "NnFileKit",
            targets: ["NnFileKit"]
        ),
        .library(
            name: "NnConfigKit",
            targets: ["NnConfigKit"]
        ),
        .library(
            name: "NnFileTesting",
            targets: ["NnFileTesting"]
        ),
    ],
    targets: [
        .target(
            name: "NnFileKit"
        ),
        .target(
            name: "NnConfigKit",
            dependencies: ["NnFileKit"]
        ),
        .target(
            name: "NnFileTesting",
            dependencies: ["NnFileKit"]
        ),
        .testTarget(
            name: "NnFileKitTests",
            dependencies: [
                "NnFileKit"
            ]
        ),
        .testTarget(
            name: "NnConfigKitTests",
            dependencies: [
                "NnConfigKit",
                "NnFileTesting",
            ]
        ),
    ]
)
