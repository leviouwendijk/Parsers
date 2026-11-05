import enum Grammar.Grammar
import GrammarParsing

public extension Prebuilt.DateSpecificationParser {
    /// Syntax of the ISO calendar-date literals accepted by DateSpecificationParser.
    /// Calendar validity, time zones, and date inference remain semantic concerns.
    static func isoLanguage() throws -> Grammar.Language {
        try Grammar.Language(
            name: "iso_date",
            start: "date",
            productions: [
                .init(name: "date", expression: .sequence([
                    .field("year", .symbol(.terminal("digits"))),
                    .literal("-"),
                    .field("month", .symbol(.terminal("digits"))),
                    .literal("-"),
                    .field("day", .symbol(.terminal("digits")))
                ]))
            ],
            terminals: [
                .init(name: "digits", pattern: .regex("[+]?[0-9]+"), role: "number")
            ]
        )
    }
}

extension Prebuilt.DateSpecificationParser {
    internal static func parseISOSyntax(_ source: String) throws -> GrammarParser.Node {
        try isoCompiler.get().parse(source)
    }

    private static let isoCompiler: Result<GrammarParser, any Swift.Error> = Result {
        try GrammarParser(language: isoLanguage())
    }
}
