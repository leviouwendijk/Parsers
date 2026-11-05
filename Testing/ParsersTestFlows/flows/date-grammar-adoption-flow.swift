import Foundation
import enum Grammar.Grammar
import GrammarParsing
import GrammarSyntax
import GrammarTreeSitter
import Lexing
import Parsers
import SyntaxLSP
import Testing

extension ParserTestSuite {
    static let grammarISODateSuite = TestSuite("date.grammar.adoption") {
        Test("ISO date literals use the canonical grammar and preserve calendar semantics") {
            let zone = TimeZone(secondsFromGMT: 0) ?? .current
            let parsed = try Prebuilt.DateSpecificationParser.parse(
                "2024-02-29", config: .init(timeZone: zone)
            )
            guard case .absolute(let value) = parsed else {
                try Expect.true(false, "literal must resolve to an absolute date")
                return
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let fields = calendar.dateComponents([.year, .month, .day], from: value)
            try Expect.equal(fields.year, 2024, "year")
            try Expect.equal(fields.month, 2, "month")
            try Expect.equal(fields.day, 29, "day")

            try Expect.throwsError("calendar validation rejects invalid leap day") {
                _ = try Prebuilt.DateSpecificationParser.parse("2025-02-29")
            }
            do {
                _ = try Prebuilt.DateSpecificationParser.parse("2024/02/29")
                try Expect.true(false, "invalid separators should be rejected")
            } catch let error as Prebuilt.DateSpecificationParserError {
                try Expect.equal(error, .invalidLiteral("2024/02/29"), "existing error type")
            }
            _ = try Prebuilt.DateSpecificationParser.parse("infer 15")
            _ = try Prebuilt.DateSpecificationParser.parse(
                "1700000000", config: .init(allowUnixEpoch: true)
            )
            try Expect.throwsError("trailing source is not silently ignored") {
                _ = try Prebuilt.DateSpecificationParser.parse("2024-02-29xyz")
            }
        }
        Test("real ISO syntax yields the same structured fields and Syntax/LSP tokens") {
            let language = try Prebuilt.DateSpecificationParser.isoLanguage()
            let source = "2024-02-29"
            let lexing = try GrammarLexer(language: language).lex(source)
            let significant = lexing.tokens.compactMap { located -> String? in
                guard case .grammar_terminal(_, let raw) = located.token else { return nil }
                return raw
            }
            try Expect.equal(significant.joined(), source, "lexing preserves every source byte")
            let compiled = try GrammarParser(language: language)
            let structured = try compiled.parseStructured(source)
            try Expect.equal(structured.root.name, "date", "production name")
            try Expect.equal(structured.match.captures.map(\.name),
                             ["year", "month", "day"], "grammar field names")
            try Expect.equal(structured.match.captures.map(\.value),
                             ["2024", "02", "29"], "lossless source values")
            try Expect.equal(structured.match.range.offsets, 0..<source.count,
                             "entire source is consumed")

            let projection = try GrammarSyntaxProjection(language: language, source: source)
            try Expect.equal(projection.tree.name, "date", "same root")
            let legend = try SyntaxLSP.Legend(types: ["number"])
            let tokens = try SyntaxLSP.project(document: projection.document,
                                               legend: legend, rules: [
                .init(selector: .init(role: .number, layer: .lexical), type: "number")
            ])
            try Expect.equal(SyntaxLSP.encode(tokens), [
                0, 0, 4, 0, 0,
                0, 5, 2, 0, 0,
                0, 3, 2, 0, 0
            ], "source-accurate LSP number spans")
        }
        Test("native and Tree-sitter agree on real ISO date syntax") {
            let language = try Prebuilt.DateSpecificationParser.isoLanguage()
            try ISODateGrammarParity.run(language)
        }
    }
}

private enum ISODateGrammarParity {
    static func run(_ language: Grammar.Language) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iso-date-grammar-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let src = directory.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let artifacts = try GrammarTreeSitter.emit(language)
        try artifacts.grammarJSON.write(to: src.appendingPathComponent("grammar.json"),
                                        atomically: true, encoding: .utf8)
        try #"{"name":"tree-sitter-iso-date","version":"0.1.0"}"#.write(
            to: directory.appendingPathComponent("package.json"),
            atomically: true, encoding: .utf8
        )
        let configuration = #"""
        {
            "grammars": [{
                "name": "iso_date",
                "scope": "source.iso_date",
                "path": ".",
                "file-types": ["isodate"]
            }],
            "metadata": {
                "version": "0.1.0",
                "authors": [{"name": "Grammar Conformance"}]
            }
        }
        """#
        try configuration.write(to: directory.appendingPathComponent("tree-sitter.json"),
                                atomically: true, encoding: .utf8)

        let generated = try command(["generate", "src/grammar.json"], in: directory)
        try Expect.equal(generated.status, 0, "Tree-sitter generation: \(generated.output)")

        let parser = try GrammarParser(language: language)
        let fixtures: [(text: String, valid: Bool)] = [
            ("2024-02-29", true),
            ("+2024-+02-+29", true),
            ("2024-02", false),
            ("2024/02/29", false),
            ("2024-02-29tail", false)
        ]
        for (index, fixture) in fixtures.enumerated() {
            let path = directory.appendingPathComponent("date-\(index).isodate")
            try fixture.text.write(to: path, atomically: true, encoding: .utf8)
            let nativeAccepted = (try? parser.parse(fixture.text)) != nil
            let result = try command(["parse", "--grammar-path", directory.path, path.path],
                                     in: directory)
            let treeSitterAccepted = result.status == 0
                && !result.output.contains("(ERROR")
                && !result.output.contains("(MISSING")
            try Expect.equal(nativeAccepted, fixture.valid, "native fixture \(index)")
            try Expect.equal(treeSitterAccepted, fixture.valid,
                             "Tree-sitter fixture \(index): \(result.output)")
            if index == 0 {
                try Expect.true(result.output.contains("year:"), "Tree-sitter year field")
                try Expect.true(result.output.contains("month:"), "Tree-sitter month field")
                try Expect.true(result.output.contains("day:"), "Tree-sitter day field")
            }
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
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
