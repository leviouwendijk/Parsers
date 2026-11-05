import enum Grammar.Grammar
import GrammarParsing

public extension Pkl {
    /// The supported Pkl configuration subset, independent of model decoding.
    /// Right-recursive value productions avoid left recursion and precedence.
    static func language() throws -> Grammar.Language {
        let entry = Grammar.Expression.sequence([
            .field("name", .symbol(.terminal("identifier"))),
            .choice([
                .sequence([
                    .literal("="),
                    .field("value", .symbol(.production("value")))
                ]),
                .field("value", .symbol(.production("brace")))
            ])
        ])
        let element = Grammar.Expression.sequence([
            .symbol(.production("value")),
            .optional(.literal(","))
        ])
        return try Grammar.Language(
            name: "pkl_subset",
            start: "document",
            productions: [
                .init(name: "document", expression: .repeat0(.symbol(.production("entry")))),
                .init(name: "entry", expression: entry),
                .init(name: "value", expression: .choice([
                    .symbol(.terminal("quoted")),
                    .symbol(.terminal("number")),
                    .symbol(.production("negative")),
                    .symbol(.production("boolean")),
                    .symbol(.production("brace")),
                    .symbol(.production("array"))
                ])),
                .init(name: "negative", expression: .sequence([
                    .literal("-"), .symbol(.terminal("number"))
                ])),
                .init(name: "boolean", expression: .choice([
                    .literal("true"), .literal("false")
                ])),
                .init(name: "brace", expression: .sequence([
                    .literal("{"),
                    .choice([
                        .symbol(.production("object_entries")),
                        .symbol(.production("elements")),
                        .blank
                    ]),
                    .literal("}")
                ])),
                .init(name: "object_entries", expression: .repeat1(.symbol(.production("entry")))),
                .init(name: "elements", expression: .repeat1(.symbol(.production("element")))),
                .init(name: "array", expression: .sequence([
                    .literal("["),
                    .repeat0(.symbol(.production("element"))),
                    .literal("]")
                ])),
                .init(name: "element", expression: element)
            ],
            terminals: [
                .init(name: "quoted", pattern: .regex(#""([^"\\]|\\.)*""#), role: "string"),
                .init(name: "identifier", pattern: .regex(#"[\p{L}_][\p{L}\p{Nd}_.-]*"#), role: "variable"),
                .init(name: "number", pattern: .regex(#"[0-9]+(?:\.[0-9]*)?"#), role: "number")
            ],
            extras: [
                .pattern(#"[ \t\r\n]+"#),
                .pattern(#"//[^\r\n]*"#),
                .pattern(#"#[^\r\n]*"#),
                .pattern(#"/\*([^*]|\*+[^*/])*\*+/"#)
            ]
        )
    }
}

extension Pkl {
    static func parseGrammarTree(_ source: String, filePath: String? = nil) throws -> GrammarParser.Node {
        try grammarCompiler.get().parse(source, filePath: filePath)
    }

    private static let grammarCompiler: Result<GrammarParser, any Swift.Error> = Result {
        try GrammarParser(language: language())
    }
}
