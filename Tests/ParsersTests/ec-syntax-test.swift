import Foundation
import Testing
import Parsers

// MARK: - Policy setup

private func ecPolicies() -> BlockPolicyTable {
    BlockPolicyTable(
        predetermined: [
            ["details"]: .init(
                delimiter: .braces,
                options: .init(
                    trimWhitespace: true,
                    unquoteIfWrapped: true,
                    unescapeCommon: true,
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

private func lexEC(
    _ source: String,
    sets: LexingSets = LexingSets(
        keywords: [
            "entity","use","alias","domain",
            "content","variant","subvariant",
            "details"
        ],
        idents: [],
        stringBlockKeywords: ["details"]
    ),
    configure: (inout LexerOptions) -> Void = { _ in }
) -> TokenCursor {
    var opts = LexerOptions()
    opts.emit_whitespace = false
    opts.emit_comments = false
    opts.emit_newlines = false
    opts.block_string_policies = ecPolicies()
    configure(&opts)

    var lx = Lexer(source: source, sets: sets, options: opts)
    let (tokens, lines) = lx.collectAllTokensWithLineMap()
    return TokenCursor(tokens, lineMap: lines, filePath: "fixtures/accounting.ec")
}

// MARK: - Tiny helpers

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

private func expectIdent(_ cur: inout TokenCursor) -> String {
    switch cur.peek() {
    case .identifier(let s)?:
        cur.advance()
        return s
    default:
        Issue.record("expected identifier, got \(String(describing: cur.peek()))")
        cur.advance()
        return ""
    }
}

private func consumeAssignmentLine(_ cur: inout TokenCursor) -> (lhs: [String], value: Decimal)? {
    // path: ident ( '#' ident )? ( '.' ident ( '#' ident )? )*
    func readPathSegment(_ c: inout TokenCursor) -> String? {
        guard case .identifier(let head)? = c.peek() else { return nil }
        c.advance()
        var seg = head
        if case .hash? = c.peek() {
            c.advance()
            seg += "#" + expectIdent(&c)
        }
        return seg
    }

    guard let seg0 = readPathSegment(&cur) else { return nil }
    var path = [seg0]
    while case .dot? = cur.peek() {
        cur.advance()
        guard let s = readPathSegment(&cur) else { return nil }
        path.append(s)
    }

    #expect(expectToken(&cur, .equals), "assignment '='")
    var value: Decimal = 0
    switch cur.peek() {
    case .number(let d, _)?:
        value = d
        cur.advance()
    default:
        Issue.record("expected number after '=', got \(String(describing: cur.peek()))")
        return nil
    }
    // optional trailing comma
    if case .comma? = cur.peek() { cur.advance() }
    return (path, value)
}

// MARK: - Tests

@Test
func ec_entities_minimal_parse() {
    let text = #"""
    // combined products and services
    entity {
        use alias puppy
        domain combined

        content {
            service.session = 3
            product.leash = 1
            service.docs_premium_access = 3
            product.course#puppy_fundamenten = 1
        }
    }

    // product with variants/subvariants
    entity {
        use alias leash
        domain physical

        variant {
            use alias any
        }

        variant {
            use alias 10mm
            subvariant { use alias black }
            subvariant { use alias blue }
            subvariant { use alias gray }
        }
    }

    // docs
    entity {
        use alias behavior_teaching_manual
        details { "pdf that describeds steps for teaching behaviors" }
        domain digital
    }
    """#

    var cur = lexEC(text) { opts in
        opts.comments = [.line(prefix: "//")]
    }

    var entityCount = 0
    var aliases: [String] = []
    var detailsPayloads: [String] = []
    var contentPaths: [[String]] = []

    while let t = cur.peek(), t != .eof {
        if t == .keyword("entity") {
            cur.advance()
            #expect(expectToken(&cur, .left_brace), "entity block")

            var sawContent = false
            var done = false
            while let k = cur.peek(), k != .eof, !done {
                switch k {
                case .keyword("use"):
                    cur.advance()
                    expectKeyword(&cur, "alias")
                    let a = expectIdent(&cur)
                    #expect(!a.isEmpty)
                    aliases.append(a)

                case .keyword("domain"):
                    cur.advance()
                    _ = expectIdent(&cur)

                case .keyword("content"):
                    cur.advance()
                    sawContent = true
                    #expect(expectToken(&cur, .left_brace), "content {")
                    while cur.peek() != .right_brace, cur.peek() != .eof {
                        let tok = cur.peek()
                        if case .identifier = tok {
                            if let (lhs, _) = consumeAssignmentLine(&cur) {
                                contentPaths.append(lhs)
                                continue
                            }
                        }
                        cur.advance()
                    }
                    #expect(expectToken(&cur, .right_brace), "content }")

                case .keyword("details"):
                    cur.advance()
                    #expect(expectToken(&cur, .left_brace), "details {")
                    switch cur.peek() {
                    case .string(let s)?:
                        detailsPayloads.append(s)
                        cur.advance()
                    default:
                        Issue.record("expected .string inside details block")
                    }
                    #expect(expectToken(&cur, .right_brace), "details }")

                case .right_brace:
                    cur.advance()
                    entityCount += 1
                    done = true

                default:
                    cur.advance()
                }
            }

            if entityCount == 1 { #expect(sawContent, "first entity should have content block") }
        } else {
            cur.advance()
        }
    }

    #expect(entityCount == 3)
    #expect(aliases.contains("puppy"))
    #expect(aliases.contains("leash"))
    #expect(aliases.contains("behavior_teaching_manual"))

    // #expect(contentPaths.contains(["service","session"]))
    // #expect(contentPaths.contains(["product","leash"]))
    // #expect(contentPaths.contains(["service","docs_premium_access"]))
    // #expect(contentPaths.contains(["product","course#puppy_fundamenten"]))

    #expect(contentPaths.contains(["service.session"]))
    #expect(contentPaths.contains(["product.leash"]))
    #expect(contentPaths.contains(["service.docs_premium_access"]))
    #expect(contentPaths.contains(["product.course#puppy_fundamenten"]))

    #expect(detailsPayloads.first?.contains("pdf that describeds steps") == true)
}
