import Foundation
import Testing
import Parsers

// tiny helper: tokenizer with minimal sets
private func glex(
    _ source: String,
    keywords: Set<String>,
    blockKeys: Set<String> = []
) -> TokenCursor {
    lex(
        source,
        sets: LexingSets(
            keywords: keywords,
            idents: [],
            stringBlockKeywords: blockKeys
        )
    )
}

@Test
func grammar_map_and_list_values() async throws {
    // pairs { a = "x"; b = "y" }
    let src = #"""
    pairs { a = "x"; b = "y" }
    """#
    let cur = glex(src, keywords: ["pairs"])

    // values table
    let pc = ParserComponents.basic()
    // ensure "string" exists (it does in .basic())
    // build node spec that maps to SyntaxNode.map
    let node = GrammarNode(
        name: "pairs",
        opener: .raw("pairs"),
        delimiter: .braces,
        order: .unordered,
        fields: [
            // treat whole body as a single "kv" map(String -> String)
            // then GrammarCompiler will fold into a GResult.object and then we can fold -> SyntaxNode.map
            GrammarField("kv", .map(.val("string"), sep: .semicolon, allowUnknownKeys: true), multiplicity: .one)
        ]
    )

    let grammar = Grammar(
        nodes: [node],
        values: pc,
        child: { AnyTokenParser { _ in .failure(Diagnostic("no child")) } }
    )

    let parser = GrammarCompiler.compile(grammar, node: "pairs")
    switch parser.parse(cur) {
    case .failure(let d): Issue.record("unexpected failure: \(d)")
    case .success(let res, _):
        // fold to SyntaxNode and inspect
        let folded = fold(res)
        guard case .map(let dict) = folded else {
            Issue.record("expected map, got \(folded)")
            return
        }
        // #expect(dict["_type"] == SyntaxNode.atom("pairs"))
        // _type must be .atom("pairs")
        if case SyntaxNode.atom("pairs")? = dict["_type"] {
            #expect(Bool(true))
        } else {
            Issue.record("_type not 'pairs'")
        }
        #expect(dict["kv"] != nil)
        // if case let .map(kvs)? = dict["kv"] {
        //     #expect(kvs["a"] == SyntaxNode.string("x"))
        //     #expect(kvs["b"] == SyntaxNode.string("y"))
        if case let .map(kvs)? = dict["kv"] {
            // kvs["a"] == .string("x")
            if case SyntaxNode.string("x")? = kvs["a"] { #expect(true) }
            else { Issue.record("kvs['a'] not \"x\"") }
            // kvs["b"] == .string("y")
            if case SyntaxNode.string("y")? = kvs["b"] { #expect(true) }
            else { Issue.record("kvs['b'] not \"y\"") }
        } else {
            Issue.record("missing kv map")
        }
    }
}

@Test
func grammar_optional_and_many_fields_validation() async throws {
    // widget {
    //   id foo
    //   tags a, b, c
    // }
    let src = """
    widget { id foo; tags a, b, c }
    """
    let cur = glex(src, keywords: ["widget","id","tags"])

    let pc = ParserComponents.basic()
    // treat "ident" as String
    let idField  = GrammarField("id",   .val("ident"), multiplicity: .optional())
    let tagsField = GrammarField("tags", .list(.val("ident"), sep: .comma), multiplicity: .one)

    // validator: require 'tags'
    let node = GrammarNode(
        name: "widget",
        opener: .raw("widget"),
        delimiter: .braces,
        order: .unordered,
        fields: [idField, tagsField],
        validate: GValidators.requireKeys(["tags"])
    )

    let grammar = Grammar(
        nodes: [node],
        values: pc,
        child: { AnyTokenParser { _ in .failure(Diagnostic("no child")) } }
    )

    let parser = GrammarCompiler.compile(grammar, node: "widget")
    switch parser.parse(cur) {
    case .failure(let d): Issue.record("unexpected failure: \(d)")
    case .success(let res, _):
        // .object -> fold -> check content
        let folded = fold(res)
        guard case .map(let dict) = folded else {
            Issue.record("expected map")
            return
        }
        // if case .list(let arr)? = dict["tags"] {
        if case let .list(arr)? = dict["tags"] {
            #expect(arr.count == 3)
            // #expect(arr.first == SyntaxNode.atom("a"))
            if let first = arr.first, case SyntaxNode.atom("a") = first {
                #expect(true)
            } else {
                Issue.record("first tag not 'a'")
            }
        } else {
            Issue.record("tags not parsed")
        }
    }
}

@Test
func grammar_oneOf_paths() async throws {
    // value can be string OR number
    let src = #"thing { value = "hi" }"#
    let cur = glex(src, keywords: ["thing","value"])

    let pc = ParserComponents.basic()
    let node = GrammarNode(
        name: "thing",
        opener: .raw("thing"),
        delimiter: .braces,
        order: .unordered,
        fields: [
            GrammarField(
                "value",
                .oneOf([.val("string"), .val("number")]),
                multiplicity: .one
            )
        ]
    )
    let grammar = Grammar(nodes: [node], values: pc, child: { AnyTokenParser { _ in .failure(Diagnostic("")) } })
    let p = GrammarCompiler.compile(grammar, node: "thing")
    switch p.parse(cur) {
    case .failure(let d): Issue.record("unexpected: \(d)")
    case .success(let res, _):
        let folded = fold(res)
        guard case let .map(m) = folded, case SyntaxNode.string("hi")? = m["value"] else {
            Issue.record("expected value=string 'hi'")
            return
        }
    }
}
