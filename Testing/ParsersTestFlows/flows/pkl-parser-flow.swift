import Parsers
import Position
import Testing

extension ParserTestSuite {
    static let pklParserSuite = TestSuite(
        "pkl.syntax.parser",
        title: "Pkl token grammar with Parsing and Position",
        tags: ["parsers", "pkl", "syntax", "regression"]
    ) {
        Test("modern build-object shape parses nested blocks and string lists") {
            let source = """
                // modern configuration
                uuid = "2D45ED1F-3F26-4C11-93D1-BB92E9C1A734"
                name = "demo"
                types { "binary" "script", }
                versions {
                    release { major = 1 minor = 2 patch = 3 }
                }
                compile {
                    use = false
                    arguments { "-c", "debug" }
                }
                details = "test"
                author = "levi"
                update = "manual"
                """
            let document = try Pkl.parse(source, filePath: "/repo/build-object.pkl")
            try Expect.equal(document.entries.count, 8, "pkl.modern.entries")
            try Expect.equal(document.entries[1].value, .string("demo"), "pkl.modern.name")
            try Expect.equal(
                document.entries(named: "types").first?.value,
                .collection([.string("binary"), .string("script")]),
                "pkl.modern.types"
            )

            guard case .block(let versions)? = document.entries(named: "versions").first?.value,
                  case .block(let release)? = versions.first?.value else {
                throw Pkl.SyntaxFailure(.init("Missing nested versions.release block"))
            }
            try Expect.equal(release.map(\.name), ["major", "minor", "patch"], "pkl.modern.version.keys")
            try Expect.equal(release.map(\.value), [.integer(1), .integer(2), .integer(3)], "pkl.modern.version.values")

            guard case .block(let compile)? = document.entries(named: "compile").first?.value else {
                throw Pkl.SyntaxFailure(.init("Missing compile block"))
            }
            try Expect.equal(compile.first?.value, .boolean(false), "pkl.modern.compile.use")
            try Expect.equal(
                compile.last?.value,
                .collection([.string("-c"), .string("debug")]),
                "pkl.modern.compile.arguments"
            )
        }

        Test("legacy and compiled shapes parse without plate models") {
            let legacy = try Pkl.parse("version { major = 0 minor = 4 patch = 2 }\ntype = \"binary\"")
            let compiled = try Pkl.parse("compiled { version { major = 1 minor = 0 patch = 0 } arguments { \"-O\" } }")
            try Expect.equal(legacy.entries.map(\.name), ["version", "type"], "pkl.legacy.names")
            try Expect.equal(compiled.entries.map(\.name), ["compiled"], "pkl.compiled.root")
            guard case .block(let members) = compiled.entries[0].value else {
                throw Pkl.SyntaxFailure(.init("Missing compiled block"))
            }
            try Expect.equal(members.map(\.name), ["version", "arguments"], "pkl.compiled.members")
        }

        Test("duplicate keys and character spans survive tokenization") {
            let source = "// note\nname = \"🎓\"\nname = \"two\""
            let document = try Pkl.parse(source)
            try Expect.equal(document.entries(named: "name").count, 2, "pkl.duplicates")
            let second = document.entries[1]
            try Expect.equal(second.range.end.offset, source.count, "pkl.spans.end")
            let display = LineTable(text: source).displaySpan(for: second.range)
            try Expect.equal(display.start.line, 3, "pkl.spans.line")
            try Expect.equal(display.start.column, 1, "pkl.spans.column")
        }

        Test("bracket collections, booleans, signed integers, and escaped strings") {
            let source = """
                enabled = true
                retry = -2
                names = ["a", "b",]
                message = "line\\nnext"
                """
            let document = try Pkl.parse(source)
            try Expect.equal(document.entries[0].value, .boolean(true), "pkl.scalar.boolean")
            try Expect.equal(document.entries[1].value, .integer(-2), "pkl.scalar.signed-integer")
            try Expect.equal(document.entries[2].value, .collection([.string("a"), .string("b")]), "pkl.list.brackets")
            try Expect.equal(document.entries[3].value, .string("line\nnext"), "pkl.scalar.escaped-string")
        }

        Test("malformed inputs return diagnostics rather than partial documents") {
            try Expect.throwsError("pkl.unterminated-block") {
                _ = try Pkl.parse("compile { use = true")
            }
            try Expect.throwsError("pkl.non-integer") {
                _ = try Pkl.parse("major = 1.5")
            }
            try Expect.throwsError("pkl.unknown-value") {
                _ = try Pkl.parse("enabled = perhaps")
            }
            try Expect.throwsError("pkl.trailing-brace") {
                _ = try Pkl.parse("name = \"a\" }")
            }
        }
    }
}
