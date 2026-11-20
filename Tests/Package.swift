// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParsersTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [

        // testing
        .executable(
            name: "t_parsers",
            targets: ["ParsersTestFlows"]
        ),
        .executable(
            name: "t_parsers_invariance",
            targets: ["ParsersInvariantTests"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Parsing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Grammar.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Lexing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Syntax.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Testing.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "ParsersTestFlows",
            dependencies: [
                .product(name: "Parsers", package: "Parsers"),
                .product(name: "ParsersStructuredContent", package: "Parsers"),
                .product(name: "GrammarParsing", package: "Parsing"),
                .product(name: "GrammarSyntax", package: "Parsing"),
                .product(name: "Grammar", package: "Grammar"),
                .product(name: "GrammarTreeSitter", package: "Grammar"),
                .product(name: "Lexing", package: "Lexing"),
                .product(name: "SyntaxLSP", package: "Syntax"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Position", package: "Position"),
                .product(name: "Testing", package: "Testing"),
            ]
        ),
        .executableTarget(
            name: "ParsersInvariantTests",
            dependencies: [
                .product(name: "Parsers", package: "Parsers"),
                .product(name: "Testing", package: "Testing"),
            ]
        ),
    ]
)
