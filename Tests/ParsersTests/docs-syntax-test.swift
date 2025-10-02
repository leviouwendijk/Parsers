import Foundation
import Testing
import Parsers

// MARK: - Policy setup

private func docsPolicies() -> BlockPolicyTable {
    BlockPolicyTable(
        predetermined: [
            ["body"]: .init(
                delimiter: .braces,
                options: .init(
                    trimWhitespace: true,
                    unquoteIfWrapped: false,
                    unescapeCommon: false,
                    normalizeNewlines: true
                )
            )
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

// MARK: - Lex helper

private func lexDocs(
    _ source: String,
    sets: LexingSets = LexingSets(
        keywords: [
            "config","url",
            "category","label","hide","sort","weights","strategy",
            "article","self","version","major","minor","patch",
            "metadata","published_at","duration_minutes","tags",
            "body",
            "primacy","relevance","engagement","manual",
            "true","false"
        ],
        idents: [],
        stringBlockKeywords: ["body"]
    ),
    configure: (inout LexerOptions) -> Void = { _ in }
) -> TokenCursor {
    var opts = LexerOptions()
    opts.emit_whitespace = false
    opts.emit_comments = false
    opts.emit_newlines = false
    opts.block_string_policies = docsPolicies()
    configure(&opts)

    var lx = Lexer(source: source, sets: sets, options: opts)
    let (tokens, lines) = lx.collectAllTokensWithLineMap()
    return TokenCursor(tokens, lineMap: lines, filePath: "fixtures/index.hdoc")
}

// MARK: - Helpers

@discardableResult
private func expectToken(_ cur: inout TokenCursor, _ tok: Token, _ note: String = "") -> Bool {
    let got = cur.peek()
    let ok = got == tok
    #expect(ok, "\(note.isEmpty ? "" : note + " — ")expected \(tok), got \(String(describing: got))")
    if ok { cur.advance() }
    return ok
}

private func expectKeyword(_ cur: inout TokenCursor, _ word: String) {
    let got = cur.peek()
    #expect(got == .keyword(word), "expected keyword(\(word)), got \(String(describing: got))")
    cur.advance()
}

private func expectStringLit(_ cur: inout TokenCursor) -> String {
    switch cur.peek() {
    case .string(let s)?:
        cur.advance()
        return s
    default:
        Issue.record("expected .string, got \(String(describing: cur.peek()))")
        cur.advance()
        return ""
    }
}

private func expectIntLike(_ cur: inout TokenCursor) -> Int {
    switch cur.peek() {
    case .number(let d, _)?:
        cur.advance()
        return NSDecimalNumber(decimal: d).intValue
    default:
        Issue.record("expected number/integer, got \(String(describing: cur.peek()))")
        cur.advance()
        return 0
    }
}

private func readStringArray(_ cur: inout TokenCursor) -> [String] {
    var arr: [String] = []
    #expect(expectToken(&cur, .left_bracket), "array [")
    while cur.peek() != .right_bracket, cur.peek() != .eof {
        let t = cur.peek()
        if case .string(let s) = t {
            arr.append(s)
            cur.advance()
            if cur.peek() == .comma { cur.advance() }
            continue
        }
        cur.advance()
    }
    #expect(expectToken(&cur, .right_bracket), "array ]")
    return arr
}

private func skipBalancedBlock(_ cur: inout TokenCursor) {
    #expect(expectToken(&cur, .left_brace), "block {")
    var depth = 1
    while depth > 0, let t = cur.peek(), t != .eof {
        if t == .left_brace { depth += 1 }
        if t == .right_brace { depth -= 1 }
        cur.advance()
    }
}

@inline(__always)
private func isWord(_ t: Token, _ w: String) -> Bool {
    switch t {
    case .keyword(w), .identifier(w): return true
    default: return false
    }
}

private func expectWord(_ cur: inout TokenCursor, _ word: String) {
    guard let t = cur.peek(), isWord(t, word) else {
        Issue.record("expected \(word), got \(String(describing: cur.peek()))")
        return
    }
    cur.advance()
}

private func expectTrue(_ cur: inout TokenCursor) {
    guard let t = cur.peek(), isWord(t, "true") else {
        Issue.record("expected true, got \(String(describing: cur.peek()))")
        return
    }
    cur.advance()
}

private func expectFalse(_ cur: inout TokenCursor) {
    guard let t = cur.peek(), isWord(t, "false") else {
        Issue.record("expected false, got \(String(describing: cur.peek()))")
        return
    }
    cur.advance()
}

// MARK: - Tests

@Test
func docs_index_and_article_headers() {
    let text = #"""
    // index file:
    config {
        url = "https://docs.hondenmeesters.nl"
    }

    category("algemeen") {
        label = "Algemeen"
        hide = false

        sort {
            primacy = 90
            relevance = 50
            engagement = 20
            manual = 10

            weights {
                primacy = 0.7
                relevance = 0.5
                engagement = 0.2
                quality = 0.8
                manual = 0.1
            }

            strategy = "blend"
        }
    }

    // article header:
    article(self)
        label = "Hoe Honden Leren"
        hide = true

        version {
           major = 0
           minor = 1
           patch = 0
        }

        sort {
            primacy = 90
            relevance = 50
            engagement = 20
            manual = 10
        }

        metadata {
            published_at = "2025-09-26T11:00:00Z"
            duration_minutes = 8
            tags = ["basis", "zit", "puppy"]
        }

        body {
            Allows

            Freer textinput
        }
    """#

    var cur = lexDocs(text) { opts in
        opts.comments = [.line(prefix: "//")]
    }

    // CONFIG block
    expectKeyword(&cur, "config")
    #expect(expectToken(&cur, .left_brace))
    expectKeyword(&cur, "url")
    #expect(expectToken(&cur, .equals))
    let url = expectStringLit(&cur)
    #expect(url.hasPrefix("https://docs.hondenmeesters.nl"))
    #expect(expectToken(&cur, .right_brace))

    // CATEGORY("algemeen") { … }
    expectKeyword(&cur, "category")
    #expect(expectToken(&cur, .left_parenthesis))
    let catName = expectStringLit(&cur)
    #expect(catName == "algemeen")
    #expect(expectToken(&cur, .right_parenthesis))

    #expect(expectToken(&cur, .left_brace))
    expectKeyword(&cur, "label"); #expect(expectToken(&cur, .equals))
    #expect(expectStringLit(&cur) == "Algemeen")

    expectKeyword(&cur, "hide"); #expect(expectToken(&cur, .equals))
    switch cur.peek() {
    case .keyword("false")?: cur.advance()
    default:
        Issue.record("expected false, got \(String(describing: cur.peek()))")
        cur.advance()
    }

    expectKeyword(&cur, "sort")
    #expect(expectToken(&cur, .left_brace))
    expectKeyword(&cur, "primacy"); 
    #expect(expectToken(&cur, .equals)); _ = expectIntLike(&cur)

    // skip until weights
    // while let t = cur.peek(), t != .keyword("weights"), t != .eof { cur.advance() }
    while let t = cur.peek(), !(isWord(t, "weights") || t == .eof) { cur.advance() }
    expectKeyword(&cur, "weights")
    skipBalancedBlock(&cur)
    expectKeyword(&cur, "strategy"); #expect(expectToken(&cur, .equals))
    #expect(expectStringLit(&cur) == "blend")
    #expect(expectToken(&cur, .right_brace)) // end sort
    #expect(expectToken(&cur, .right_brace)) // end category

    // ARTICLE(self) …
    expectKeyword(&cur, "article")
    #expect(expectToken(&cur, .left_parenthesis))
    switch cur.peek() {
    case .keyword("self")?: cur.advance()
    case .string(let s)?:  #expect(s == "self"); cur.advance()
    default:
        Issue.record("expected 'self' inside article(…); got \(String(describing: cur.peek()))")
        cur.advance()
    }
    #expect(expectToken(&cur, .right_parenthesis))

    expectKeyword(&cur, "label"); #expect(expectToken(&cur, .equals))
    #expect(expectStringLit(&cur) == "Hoe Honden Leren")

    expectKeyword(&cur, "hide"); #expect(expectToken(&cur, .equals))
    switch cur.peek() {
    case .keyword("true")?: cur.advance()
    default:
        Issue.record("expected true, got \(String(describing: cur.peek()))")
        cur.advance()
    }

    expectKeyword(&cur, "version")
    #expect(expectToken(&cur, .left_brace))
    expectKeyword(&cur, "major"); #expect(expectToken(&cur, .equals)); _ = expectIntLike(&cur)
    expectKeyword(&cur, "minor"); #expect(expectToken(&cur, .equals)); _ = expectIntLike(&cur)
    expectKeyword(&cur, "patch"); #expect(expectToken(&cur, .equals)); _ = expectIntLike(&cur)
    #expect(expectToken(&cur, .right_brace))

    expectKeyword(&cur, "sort"); skipBalancedBlock(&cur)

    expectKeyword(&cur, "metadata")
    #expect(expectToken(&cur, .left_brace))
    expectKeyword(&cur, "published_at"); #expect(expectToken(&cur, .equals))
    let published = expectStringLit(&cur)
    #expect(published.contains("2025-09-26"))
    expectKeyword(&cur, "duration_minutes"); #expect(expectToken(&cur, .equals))
    #expect(expectIntLike(&cur) == 8)
    expectKeyword(&cur, "tags"); #expect(expectToken(&cur, .equals))
    var tags = readStringArray(&cur)
    tags.sort()
    #expect(tags == ["basis","puppy","zit"])
    #expect(expectToken(&cur, .right_brace))

    expectKeyword(&cur, "body")
    #expect(expectToken(&cur, .left_brace))
    switch cur.peek() {
    case .string(let s)?:
        #expect(s.contains("Allows"))
        #expect(s.contains("Freer textinput"))
        cur.advance()
    default:
        Issue.record("expected .string in body block, got \(String(describing: cur.peek()))")
        cur.advance()
    }
    #expect(expectToken(&cur, .right_brace))

    #expect(cur.peek() == .eof)
}
