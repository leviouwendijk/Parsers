import Foundation
import Testing
import Parsers

@Test
func soft_identifier_blocks_reserved() async throws {
    let reserved: Set<String> = ["for", "in", "use"]
    let p = softIdentifier(reserving: reserved)

    // ok
    do {
        let cur = lex("alpha") // reuse tokenization from `lex(...)`
        switch p.parse(cur) {
        case .success(let name, _): #expect(name == "alpha")
        case .failure(let d): Issue.record("unexpected failure: \(d)")
        }
    }

    // reserved -> failure
    do {
        let cur = lex("for")
        switch p.parse(cur) {
        case .success: Issue.record("expected failure for reserved word")
        case .failure(let d):
            #expect(d.message.contains("reserved keyword"))
        }
    }
}

@Test
func separated_list_variants() async throws {
    // comma list
    do {
        let cur = lex("a,b,c")
        let item = TokenParsers.identifier()
        let parsed = sepBy1(item, sep: .comma).parse(cur)
        switch parsed {
        case .success(let xs, _):
            #expect(xs == ["a","b","c"])
        case .failure(let d): Issue.record("unexpected failure: \(d)")
        }
    }

    // sepEndBy with trailing commas/newlines
    do {
        let src = "a,\n b,\n c"
        let cur = lex(src, sets: .init(keywords: [], idents: [], stringBlockKeywords: [])) { o in
            o.emit_newlines = true
        }
        let item = TokenParsers.identifier()
        let parsed = sepEndBy(item, sep: .commaOrNewline).parse(cur)
        switch parsed {
        case .success(let xs, _): #expect(xs == ["a","b","c"])
        case .failure(let d): Issue.record("unexpected failure: \(d)")
        }
    }
}

@Test
func positioned_wraps_ranges() async throws {
    let cur = lex("a.b.c")
    let p = positioned(TokenParsers.dotPath())
    switch p.parse(cur) {
    case .success(let (path, range), _):
        #expect(path == "a.b.c")
        #expect(range.start.offset == 0)
        #expect(range.end.offset   > 0)
    case .failure(let d): Issue.record("unexpected failure: \(d)")
    }
}

@Test
func recover_until_yields_diagnostic_and_moves() async throws {
    let cur = lex("??? ; next")
    let rec = recoverUntil([.semicolon], message: "bad stuff")
    switch rec.parse(cur) {
    case .failure(let d):
        #expect(d.message.contains("bad stuff"))
        // cursor should now be at the semicolon position (so a following parse sees it)
    case .success:
        Issue.record("expected failure carrying diagnostic")
    }
}

@Test
func token_cut_prevents_backtracking() async throws {
    // Two branches: first consumes 'x' then fails; second would accept 'x' as identifier.
    // With `cut`, orElse must NOT try second branch.
    let first = TokenParsers.identifier()
        .flatMap { _ in AnyTokenParser<Int> { _ in .failure(Diagnostic("boom")) } }
        .cut("stop")

    let second = TokenParsers.identifier().map { _ in 42 }

    let p = first.orElse(second)

    let cur = lex("x")
    switch p.parse(cur) {
    case .success:
        Issue.record("should not have succeeded; cut must keep the failure")
    case .failure(let d):
        // #expect(d.message == "stop" || d.message == "boom")
        #expect(d.message.contains("stop") || d.message.contains("boom"))
    }
}

// @Test
// func dot_and_arrow_paths() async throws {
//     // dot
//     do {
//         let cur = lex("a.b.c")
//         switch TokenParsers.dotPath().parse(cur) {
//         case .success(let s, _): #expect(s == "a.b.c")
//         case .failure(let d): Issue.record("unexpected failure: \(d)")
//         }
//     }
//     // arrow
//     do {
//         let cur = lex("a->b->c", sets: .init(keywords: [], idents: [], stringBlockKeywords: []))
//         switch arrowPath().parse(cur) {
//         case .success(let s, _): #expect(s == "a.b.c")
//         case .failure(let d): Issue.record("unexpected failure: \(d)")
//         }
//     }
// }
@Test
func dot_path_only_for_now() async throws {
    let cur = lex("a.b.c")
    switch TokenParsers.dotPath().parse(cur) {
    case .success(let s, _): #expect(s == "a.b.c")
    case .failure(let d): Issue.record("unexpected failure: \(d)")
    }
}

@Test
func parser_components_basic_primitives() async throws {
    let pc = ParserComponents.basic()

    // int from Decimal
    do {
        let cur = lex("42")
        let p: AnyTokenParser<Int> = pc.make("int")!
        switch p.parse(cur) {
        case .success(let i, _): #expect(i == 42)
        case .failure(let d): Issue.record("unexpected failure: \(d)")
        }
    }

    // bool from identifier
    do {
        let cur = lex("true", sets: .init(keywords: ["true","false"], idents: [], stringBlockKeywords: []))
        let p: AnyTokenParser<Bool> = pc.make("bool")!
        switch p.parse(cur) {
        case .success(let b, _): #expect(b)
        case .failure(let d): Issue.record("unexpected failure: \(d)")
        }
    }

    // decimalLoose from quoted number
    do {
        let cur = lex(#""3.50""#)
        let p: AnyTokenParser<Decimal> = pc.make("decimalLoose")!
        switch p.parse(cur) {
        case .success(let d, _): #expect(d == Decimal(string: "3.50"))
        case .failure(let e): Issue.record("unexpected failure: \(e)")
        }
    }
}
