import Foundation
import enum Grammar.Grammar
import GrammarParsing
import GrammarSyntax
import GrammarTreeSitter
import Lexing
import Parsers
import Parsing
import Position
import SyntaxLSP
import Testing

extension ParserTestSuite {
    static let pklGrammarSuite = TestSuite(
        "pkl.grammar.conformance",
        title: "Canonical Pkl grammar and legacy differential tests"
    ) {
        Test("canonical and legacy Pkl parsers preserve values, order and Character spans") {
            for (index, source) in PklGrammarFixtures.valid.enumerated() {
                let expected: Pkl.Document
                do {
                    expected = try PklGrammarFixtures.legacy(source)
                } catch {
                    try Expect.true(false, "Legacy rejected valid fixture \(index): \(error). Source: \(String(reflecting: source))")
                    continue
                }

                let actual: Pkl.Document
                do {
                    actual = try Pkl.parseCanonical(source, filePath: "/tmp/case-\(index).pkl")
                } catch {
                    try Expect.true(false, "Canonical rejected valid fixture \(index): \(error). Source: \(String(reflecting: source))")
                    continue
                }

                try Expect.equal(actual, expected, "Pkl fixture \(index) maintains semantics and spans")
            }
        }

        Test("invalid Pkl remains invalid with exact UTF-8 diagnostics") {
            for (index, source) in PklGrammarFixtures.invalid.enumerated() {
                let legacyRejected = (try? PklGrammarFixtures.legacy(source)) == nil
                let canonicalRejected = (try? Pkl.parseCanonical(source)) == nil
                try Expect.true(legacyRejected, "legacy fixture \(index) rejects malformed source")
                try Expect.true(canonicalRejected, "canonical fixture \(index) rejects malformed source")
            }
            let source = "name = \"é\"\nmajor = 1.5"
            let offset = "name = \"é\"\nmajor = ".utf8.count
            do {
                _ = try Pkl.parseCanonical(source)
                try Expect.true(false, "fractional integer must fail")
            } catch let failure as Pkl.SyntaxFailure {
                try Expect.equal(failure.diagnostic.utf8Range?.lowerBound.offset,
                                 offset, "invalid number start in bytes")
                try Expect.equal(failure.diagnostic.utf8Range?.upperBound.offset,
                                 source.utf8.count, "invalid number end in bytes")
            }
        }

        Test("Pkl grammar exposes structural captures and Syntax/LSP spans") {
            let source = "name = \"é\"\nversions { release { major = 1 } }"
            let language = try Pkl.language()
            let lexer = try GrammarLexer(language: language)
            let lexing = try lexer.lex(source)
            try Expect.equal(lexing.diagnostics.count, 0, "no lexical errors")
            let coverage = lexing.tokens.compactMap { token -> String? in
                let range = token.range
                guard range.lowerBound.offset != range.upperBound.offset else { return nil }
                let lower = source.utf8.index(source.utf8.startIndex, offsetBy: range.lowerBound.offset)
                let upper = source.utf8.index(source.utf8.startIndex, offsetBy: range.upperBound.offset)
                return String(source[lower..<upper])
            }.joined()
            try Expect.equal(coverage, source, "canonical tokens cover full source without gaps")

            let parser = try GrammarParser(language: language)
            let structured = try parser.parseStructured(source)
            try Expect.equal(structured.root.name, "document", "canonical production root")
            try Expect.equal(structured.root.children.filter { $0.name == "entry" }.count,
                             2, "top-level entry nodes")
            try Expect.equal(structured.match.captures.first?.name, "name", "structured key field")
            try Expect.equal(structured.match.captures.first?.value, "name", "structured key source")
            try Expect.equal(structured.match.range.end.offset, source.count, "Character range")

            let projection = try GrammarSyntaxProjection(language: language, source: source)
            try Expect.equal(projection.tree.name, "document", "Syntax root")
            let legend = try SyntaxLSP.Legend(types: ["string", "number"])
            let tokens = try SyntaxLSP.project(document: projection.document, legend: legend, rules: [
                .init(selector: .init(role: .string, layer: .lexical), type: "string"),
                .init(selector: .init(role: .number, layer: .lexical), type: "number")
            ])
            try Expect.true(!tokens.isEmpty, "SyntaxLSP projects string and number semantics")
        }

        Test("Tree-sitter and native Pkl backends recognize the same subset") {
            try PklGrammarFixtures.parity(language: Pkl.language())
        }
    }
}

private enum PklGrammarFixtures {
    static let valid: [String] = [
        "",
        "  \n\t",
        "// note\n# second comment\n/* multi\nline */",
        "name = \"alpha\" name = \"beta\"",
        "uuid = \"2D45ED1F-3F26-4C11-93D1-BB92E9C1A734\"\nname = \"demo\"\ntypes { \"binary\" \"script\", }",
        "versions { release { major = 1 minor = 2 patch = 3 } }",
        "compiled { version { major = 1 minor = 0 patch = 0 } arguments { \"-O\" } }",
        "compile { use = false arguments { \"-c\", \"debug\" } }",
        "enabled = true retry = -2 names = [\"a\", \"b\",] message = \"line\\nnext\"",
        "flags = [true, false] counts { first = 12 second = 24 }",
        "metadata {} arguments {}",
        "café = \"e\u{301}\"\r\nfoo.bar-baz = \"é\"",
        "// a\nname = \"é\"\nname = \"two\"",
        "values = { \"first\", {\"nested\"}, [true, false] }",
        "paths = [\"a\\\\b\", \"quoted \\\"string\\\"\", \"unexpected\\q\"]"
    ]

    static let invalid: [String] = [
        "name =",
        "enabled = perhaps",
        "major = 1.5",
        "major = -1.5",
        "compile { use = true",
        "compile { use = false arguments { \"-c\", \"debug\" }",
        "name = \"a\" }",
        "names = [\"a\"",
        "name = \"unterminated",
        "values { invalid }",
        "name = @"
    ]

    static func legacy(_ source: String) throws -> Pkl.Document {
        let specification = try Lexer.Specification(
            vocabulary: .init(keywords: []), recognize_dates: true
        )
        let lexing = try specification.lex(source)
        let cursor = TokenCursor(lexing: lexing, selection: .significant)
        switch Pkl.Parser().parse(cursor) {
        case .success(let document, let remainder):
            guard remainder.isEOF else {
                throw Pkl.SyntaxFailure(remainder.diagnostic("Unexpected trailing Pkl tokens"))
            }
            return document
        case .failure(let diagnostic):
            throw Pkl.SyntaxFailure(diagnostic)
        }
    }

    static func parity(language: Grammar.Language) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pkl-grammar-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let src = directory.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let artifacts = try GrammarTreeSitter.emit(language)
        try artifacts.grammarJSON.write(to: src.appendingPathComponent("grammar.json"),
                                        atomically: true, encoding: .utf8)
        try #"{"name":"tree-sitter-pkl-subset","version":"0.1.0"}"#.write(
            to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8
        )
        let metadata = #"""
        {
            "grammars": [{
                "name": "pkl_subset",
                "scope": "source.pkl_subset",
                "path": ".",
                "file-types": ["pklsubset"]
            }],
            "metadata": {
                "version": "0.1.0",
                "authors": [{"name": "Grammar Conformance"}]
            }
        }
        """#
        try metadata.write(to: directory.appendingPathComponent("tree-sitter.json"),
                           atomically: true, encoding: .utf8)
        let generated = try command(["generate", "src/grammar.json"], in: directory)
        try Expect.equal(generated.status, 0, "Tree-sitter generation: \(generated.output)")

        let native = try GrammarParser(language: language)
        let fixtures: [(String, Bool)] = [
            ("name = \"demo\"", true),
            ("versions { release { major = 1 } }", true),
            ("types { \"binary\" \"script\" }", true),
            ("names = [\"a\", \"b\"]", true),
            ("metadata {}", true),
            ("name =", false),
            ("values { invalid }", false),
            ("name = \"x\" }", false)
        ]
        for (index, fixture) in fixtures.enumerated() {
            let path = directory.appendingPathComponent("case-\(index).pklsubset")
            try fixture.0.write(to: path, atomically: true, encoding: .utf8)
            let nativeAccepted = (try? native.parse(fixture.0)) != nil
            let parsed = try command(["parse", "--grammar-path", directory.path, path.path], in: directory)
            let treeSitterAccepted = parsed.status == 0
                && !parsed.output.contains("(ERROR")
                && !parsed.output.contains("(MISSING")
            try Expect.equal(nativeAccepted, fixture.1, "native case \(index)")
            try Expect.equal(treeSitterAccepted, fixture.1,
                             "Tree-sitter case \(index): \(parsed.output)")
        }
    }

    private static func command(_ arguments: [String], in directory: URL) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tree-sitter"] + arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }
}
