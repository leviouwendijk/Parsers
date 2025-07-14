// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsers",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Parsers",
            targets: ["Parsers"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/plate.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Structures.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Extensions.git",
            branch: "master"
        ),
        // .package(
        //     url: "https://github.com/leviouwendijk/Interfaces.git",
        //     branch: "master"
        // ),
    ],
    targets: [
        .target(
            name: "Parsers",
            dependencies: [
                .product(name: "plate", package: "plate"),
                .product(name: "Structures", package: "Structures"),
                .product(name: "Extensions", package: "Extensions"),
                // .product(name: "Interfaces", package: "Interfaces"),
            ],
            resources: [
                .process("Resources")
            ],
        ),
        .testTarget(
            name: "ParsersTests",
            dependencies: [
                "Parsers",
                .product(name: "plate", package: "plate"),
                .product(name: "Structures", package: "Structures"),
                .product(name: "Extensions", package: "Extensions"),
                // .product(name: "Interfaces", package: "Interfaces"),
            ]
        ),
    ]
)
