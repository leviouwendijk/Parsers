import Foundation
import Parsing
import Position

extension Pkl {
    public struct SyntaxFailure: Error, Sendable, CustomStringConvertible {
        public let diagnostic: Diagnostic

        public init(_ diagnostic: Diagnostic) {
            self.diagnostic = diagnostic
        }

        public var description: String { diagnostic.description }
    }

    /// Parse the supported build-object Pkl subset, retaining token provenance.
    /// Semantic requirements (known fields, duplicate policy, value domains) belong to decoders.
    public static func parse(
        _ source: String,
        filePath: String? = nil
    ) throws -> Document {
        // Grammar remains the syntax-definition layer; no Pkl block shortcuts.
        // Legacy date recognition stays explicit for Pkl source parity.
        let specification = try Lexer.Specification(
            vocabulary: .init(keywords: []),
            recognize_dates: true
        )
        let lexing = try specification.lex(source)
        let cursor = TokenCursor(
            lexing: lexing,
            selection: .significant,
            filePath: filePath
        )

        switch Parser().parse(cursor) {
        case .success(let document, let remainder):
            guard remainder.isEOF else {
                throw SyntaxFailure(
                    remainder.diagnostic("Unexpected trailing Pkl tokens")
                )
            }
            return document
        case .failure(let diagnostic):
            throw SyntaxFailure(diagnostic)
        }
    }

    public struct Parser: TokenParser {
        public typealias Output = Document

        public init() {}

        public func parse(_ cursor: TokenCursor) -> TokenParseResult<Document> {
            switch Self.parseEntries(cursor, closingBrace: false) {
            case .success(let entries, let next):
                return .success(Document(entries: entries), next)
            case .failure(let diagnostic):
                return .failure(diagnostic)
            }
        }

        private static func parseEntries(
            _ cursor: TokenCursor,
            closingBrace: Bool
        ) -> TokenParseResult<[Entry]> {
            var current = cursor
            var entries: [Entry] = []

            while !current.isEOF {
                if let token = current.peek(), token.samecase(as: .right_brace) {
                    guard closingBrace else {
                        return .failure(
                            current.diagnostic("Unexpected closing brace")
                        )
                    }
                    current.advance()
                    return .success(entries, current)
                }

                switch parseEntry(current) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)
                case .success(let entry, let next):
                    guard next.index > current.index else {
                        return .failure(current.diagnostic("Pkl parser made no progress"))
                    }
                    entries.append(entry)
                    current = next
                }
            }

            if closingBrace {
                return .failure(current.diagnostic("Unterminated Pkl block: expected '}'"))
            }
            return .success(entries, current)
        }

        private static func parseEntry(_ cursor: TokenCursor) -> TokenParseResult<Entry> {
            let mark = cursor.mark()
            let name: String
            var current: TokenCursor

            switch PIdent().parse(cursor) {
            case .failure:
                return .failure(cursor.diagnostic("Expected Pkl field name"))
            case .success(let parsedName, let next):
                name = parsedName
                current = next
            }

            // Both `name = value` and `name { ... }` are accepted.
            if let token = current.peek(), token.samecase(as: .equals) {
                current.advance()
            } else if current.peek()?.samecase(as: .left_brace) != true {
                return .failure(
                    current.diagnostic("Expected '=' or '{' after '\(name)'")
                )
            }

            switch parseValue(current) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let value, let next):
                guard let range = next.sourceRange(from: mark) else {
                    return .failure(next.diagnostic("Missing source range for '\(name)'"))
                }
                return .success(Entry(name: name, value: value, range: range), next)
            }
        }

        private static func parseValue(_ cursor: TokenCursor) -> TokenParseResult<Value> {
            var next = cursor
            guard let token = next.peek() else {
                return .failure(cursor.diagnostic("Expected Pkl value"))
            }

            switch token {
            case .string(let text):
                next.advance()
                return .success(.string(text), next)
            case .number(_, let raw):
                guard let number = Int(raw) else {
                    return .failure(next.diagnostic("Expected an integer, found '\(raw)'"))
                }
                next.advance()
                return .success(.integer(number), next)
            case .dash:
                next.advance()
                guard case .number(_, let raw)? = next.peek(), let number = Int("-" + raw) else {
                    return .failure(next.diagnostic("Expected integer after '-'"))
                }
                next.advance()
                return .success(.integer(number), next)
            case .identifier("true"), .keyword("true"):
                next.advance()
                return .success(.boolean(true), next)
            case .identifier("false"), .keyword("false"):
                next.advance()
                return .success(.boolean(false), next)
            case .left_brace:
                next.advance()
                return parseBraceBody(next)
            case .left_bracket:
                next.advance()
                return parseCollection(next, closing: .right_bracket)
            default:
                return .failure(cursor.diagnostic("Expected Pkl value"))
            }
        }

        private static func parseBraceBody(_ cursor: TokenCursor) -> TokenParseResult<Value> {
            // Empty braces are syntactically ambiguous: treat them as an empty block.
            // A domain decoder may interpret an empty block as an empty string collection.
            if cursor.peek()?.samecase(as: .right_brace) == true {
                var next = cursor
                next.advance()
                return .success(.block([]), next)
            }

            // Entries begin with an identifier followed by '=' or '{'.
            if case .identifier? = cursor.peek() {
                var lookahead = cursor
                lookahead.advance()
                if lookahead.peek()?.samecase(as: .equals) == true
                    || lookahead.peek()?.samecase(as: .left_brace) == true {
                    switch parseEntries(cursor, closingBrace: true) {
                    case .success(let entries, let next):
                        return .success(.block(entries), next)
                    case .failure(let diagnostic):
                        return .failure(diagnostic)
                    }
                }
            }

            return parseCollection(cursor, closing: .right_brace)
        }

        private static func parseCollection(
            _ cursor: TokenCursor,
            closing: Token
        ) -> TokenParseResult<Value> {
            var current = cursor
            var elements: [Value] = []

            while !current.isEOF {
                if current.peek()?.samecase(as: closing) == true {
                    current.advance()
                    return .success(.collection(elements), current)
                }

                switch parseValue(current) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)
                case .success(let value, let next):
                    guard next.index > current.index else {
                        return .failure(current.diagnostic("Pkl collection parser made no progress"))
                    }
                    elements.append(value)
                    current = next
                }

                // Commas are optional for both `{ "a" "b" }` and `["a", "b"]`.
                if current.peek()?.samecase(as: .comma) == true {
                    current.advance()
                }
            }

            return .failure(
                current.diagnostic("Unterminated Pkl collection: expected '\(closing.string())'")
            )
        }
    }
}
