import Parsers
import Position
import Testing

extension ParserTestSuite {
    static let pklSyntaxSuite = TestSuite(
        "pkl.syntax.model",
        title: "Pkl syntax model preserves Position provenance",
        tags: ["parsers", "pkl", "syntax"]
    ) {
        Test("document retains duplicate keys and character ranges") {
            let source = "name = \"demo\"\nname = \"demo\""
            let first = Pkl.Entry(
                name: "name",
                value: .string("demo"),
                range: PositionRange(0..<13)
            )
            let second = Pkl.Entry(
                name: "name",
                value: .string("demo"),
                range: PositionRange(14..<27)
            )
            let document = Pkl.Document(entries: [first, second])

            try Expect.equal(document.entries.count, 2, "pkl.entries.count")
            try Expect.equal(document.entries(named: "name").count, 2, "pkl.duplicate-keys")
            try Expect.equal(document.entries[0].range.start.offset, 0, "pkl.range-start")
            try Expect.equal(document.entries[1].range.end.offset, source.count, "pkl.range-end")

            let span = LineTable(text: source).displaySpan(for: second.range)
            try Expect.equal(span.start.line, 2, "pkl.position-line")
            try Expect.equal(span.start.column, 1, "pkl.position-column")
        }

        Test("nested syntax remains typed") {
            let range = PositionRange.point(0)
            let entry = Pkl.Entry(name: "use", value: .boolean(false), range: range)
            let document = Pkl.Document(entries: [
                .init(name: "compile", value: .block([entry]), range: range),
                .init(name: "types", value: .collection([.string("binary")]), range: range)
            ])
            try Expect.equal(document.entries.count, 2, "pkl.typed-nesting")
        }
    }
}
