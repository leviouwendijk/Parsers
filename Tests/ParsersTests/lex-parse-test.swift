import Foundation
import Testing
import Parsers

private func makePolicies() -> BlockPolicyTable {
    BlockPolicyTable(
        predetermined: [
            // trim + unquote + unescape for details { "..." }
            ["details"]: .init(
                delimiter: .braces,
                options: .init(
                    trimWhitespace: true,
                    unquoteIfWrapped: true,
                    unescapeCommon: true,
                    normalizeNewlines: true
                )
            ),
            // raw { ... } = verbatim, do not trim/unquote/unescape
            ["raw"]: .init(
                delimiter: .braces,
                options: .init(
                    trimWhitespace: false,
                    unquoteIfWrapped: false,
                    unescapeCommon: false,
                    normalizeNewlines: false
                )
            ),
            // desc [ ... ] = alternate delimiters, trimmed payload
            ["desc"]: .init(
                delimiter: .brackets,
                options: .init(
                    trimWhitespace: true,
                    unquoteIfWrapped: false,
                    unescapeCommon: false,
                    normalizeNewlines: true
                )
            ),
        ],
        fallback: .init(
            delimiter: .braces,
            options: .init(
                trimWhitespace: true,
                unquoteIfWrapped: false,
                unescapeCommon: false,
                normalizeNewlines: true
            )
        )
    )
}

/// Lex the given source using our library lexer. You can override sets/policies per test.
func lex(
    _ source: String,
    sets: LexingSets = LexingSets(
        keywords: ["entry", "date", "amount", "details", "raw", "desc"],
        idents: [],
        stringBlockKeywords: ["details", "raw", "desc"]
    ),
    configure: (inout LexerOptions) -> Void = { _ in }
) -> TokenCursor {
    var opts = LexerOptions()
    // defaults for tests
    opts.emit_whitespace = false
    opts.emit_comments = false
    opts.emit_newlines = false
    opts.block_string_policies = makePolicies()
    configure(&opts)

    var lx = Lexer(source: source, sets: sets, options: opts)
    let (tokens, lines) = lx.collectAllTokensWithLineMap()
    return TokenCursor(tokens, lineMap: lines)
}

// MARK: - Mock DSL model (test-only)

struct MockEntry: Sendable, Equatable {
    var name: String
    var date: String?
    var amount: Decimal?
    var details: String?
}

// MARK: - Token parser bits (test-only)

private func Just<T: Sendable>(_ value: T) -> AnyTokenParser<T> {
    AnyTokenParser<T> { c in .success(value, c) }
}

// entry <ident> [date <date_literal>] { fields }
private func parseEntry() -> AnyTokenParser<MockEntry> {
    PKeyword("entry").flatMap { _ in
        PIdent().flatMap { name in
            parseOptionalDate().flatMap { date in
                Expect(.left_brace).flatMap { _ in
                    parseFields().flatMap { fields in
                        Expect(.right_brace).map { _ in
                            MockEntry(
                                name: name,
                                date: date,
                                amount: fields.amount,
                                details: fields.details
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct Fields: Sendable, Equatable { let amount: Decimal?; let details: String? }

/// fields := field (',' field)*
private func parseFields() -> AnyTokenParser<Fields> {
    parseField().flatMap { first in
        parseMoreFields(existing: first)
    }
}

private func parseMoreFields(existing: Fields) -> AnyTokenParser<Fields> {
    // Try: ',' field  -> recurse
    Expect(.comma).flatMap { _ in
        parseField().flatMap { f in
            parseMoreFields(existing: Fields(
                amount: f.amount ?? existing.amount,
                details: f.details ?? existing.details
            ))
        }
    }
    // Or: ε (no more fields)
    .orElse(Just(existing))
}

/// field := 'amount' '=' number | 'details' '{' string '}'
private func parseField() -> AnyTokenParser<Fields> {
    parseAmount().map { Fields(amount: $0, details: nil) }
        .orElse(parseDetails().map { Fields(amount: nil, details: $0) })
}

private func parseAmount() -> AnyTokenParser<Decimal> {
    PKeyword("amount").flatMap { _ in
        Expect(.equals).flatMap { _ in PNumber() }
    }
}

private func parseDetails() -> AnyTokenParser<String> {
    PKeyword("details").flatMap { _ in
        // In block mode the lexer returns .string(payload) between chosen delimiters.
        // For 'details' the policy trims + unquotes, so payload should be plain text.
        Expect(.left_brace).flatMap { _ in
            PString().flatMap { s in
                Expect(.right_brace).map { _ in s }
            }
        }
    }
}

private func parseOptionalDate() -> AnyTokenParser<String?> {
    PKeyword("date").flatMap { _ in PDate().map { .some($0) } }
        .orElse(Just(nil))
}

// MARK: - Tests

@Test func lexing_smoke() async throws {
    let input = #"""
    // a line comment we should ignore
    entry groceries date 2025-02-03 {
      amount = 200.00, details { "weekly food" }
    }
    """#
    var cur = lex(input) { opts in
        // enable '//' as a line comment so lexer can see & skip it
        opts.comments = [.line(prefix: "//")]
    }

    var seen: [String] = []
    while let t = cur.peek(), t != .eof {
        seen.append(t.string())
        cur.advance()
    }
    #expect(!seen.isEmpty)
    // quick spot-check of some shapes
    #expect(seen.contains("{"))
    #expect(seen.contains("groceries"))
    #expect(seen.contains("200.00"))
}

@Test func parse_entry_minimal() async throws {
    let input = #"entry test { amount = 3.14, details { "hi" } }"#
    let cur = lex(input)
    let p = parseEntry()
    switch p.parse(cur) {
    case .failure(let d):
        Issue.record("unexpected failure: \(d)")
    case .success(let entry, let next):
        #expect(entry.name == "test")
        #expect(entry.amount == Decimal(string: "3.14"))
        #expect(entry.details == "hi")   // trimmed + unquoted by policy
        #expect(next.isEOF)
    }
}

@Test func parse_entry_with_date_and_emoji() async throws {
    let input = #"entry dinner date 2025-09-12 { amount = 42, details { "🍝" } }"#
    let cur = lex(input)
    let p = parseEntry()
    switch p.parse(cur) {
    case .failure(let d):
        Issue.record("unexpected failure: \(d)")
    case .success(let entry, _):
        #expect(entry.name == "dinner")
        #expect(entry.date == "2025-09-12")
        #expect(entry.amount == Decimal(string: "42"))
        #expect(entry.details == "🍝")   // trimmed + unquoted by policy
    }
}

// --- NEW: policy-focused tests ---

@Test func block_policy_raw_preserves_verbatim() async throws {
    // 'raw' uses braces but does NOT trim or unquote.
    // So the .string payload keeps the quotes and spaces exactly as typed.
    let input = #"raw { "  hi  " }"#
    var cur = lex(input)
    // tokens: keyword("raw"), left_brace, string(payload), right_brace, eof
    #expect(cur.peek() == .keyword("raw")); cur.advance()
    #expect(cur.peek() == .left_brace);     cur.advance()

    guard case let .string(s)? = cur.peek() else {
        Issue.record("expected .string token after raw { ... }")
        return
    }
    // Payload retains quotes and spacing
    #expect(s == #" "  hi  " "#)
    cur.advance()
    #expect(cur.peek() == .right_brace)
}

@Test func block_policy_alt_delimiter_brackets() async throws {
    // 'desc' uses [ ... ] and trims
    let input = #"desc [   hello world   ]"#
    var cur = lex(input)

    #expect(cur.peek() == .keyword("desc")); cur.advance()
    #expect(cur.peek() == .left_bracket);    cur.advance()

    guard case let .string(s)? = cur.peek() else {
        Issue.record("expected .string token inside desc [ ... ]")
        return
    }
    // Trimmed by policy
    #expect(s == "hello world")
    cur.advance()
    #expect(cur.peek() == .right_bracket)
}
