// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsers",
    // platforms: [
    //     .macOS(.v13)
    // ],
    products: [
        .library(
            name: "Parsers",
            targets: ["Parsers"]),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Parsing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Methods.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Parsers",
            dependencies: [
                .product(name: "Parsing", package: "Parsing"),
                .product(name: "Methods", package: "Methods"),
                .product(name: "Primitives", package: "Primitives"),
            ],
        ),
        .testTarget(
            name: "ParsersTests",
            dependencies: [
                "Parsers",
            ]
        ),
    ]
)
