import Foundation
import Testing
import Parsers

// ===== Minimal BIN_DOCS-ish model =====
public struct SortWeights: Codable, Sendable, Equatable {
    public var primacy: Int?
    public var relevance: Int?
    public var engagement: Int?
    public var quality: Int?
    public var manual: Int?
}
public struct SortSpec: Codable, Sendable, Equatable {
    public var primacy: Int?
    public var relevance: Int?
    public var engagement: Int?
    public var manual: Int?
    public var weights: SortWeights?
    public var strategy: String?
}
public struct Semver: Codable, Sendable, Equatable {
    public var major: Int?
    public var minor: Int?
    public var patch: Int?
}
public struct ArticleMeta: Codable, Sendable, Equatable {
    public var published_at: String?
    public var duration_minutes: Int?
    public var tags: [String]?
}
public enum BodyNode: Codable, Sendable, Equatable { case raw(String) }

public struct ArticleDef: Codable, Sendable, Equatable {
    public var id: String?
    public var slug: String
    public var label: String?
    public var hide: Bool?
    public var version: Semver?
    public var sort: SortSpec?
    public var metadata: ArticleMeta?
    public var body: [BodyNode] = []
    public var category_id: String?

    public init(
        id: String? = nil, slug: String, label: String? = nil, hide: Bool? = nil,
        version: Semver? = nil, sort: SortSpec? = nil, metadata: ArticleMeta? = nil,
        body: [BodyNode] = [], category_id: String? = nil
    ) {
        self.id = id; self.slug = slug; self.label = label; self.hide = hide
        self.version = version; self.sort = sort; self.metadata = metadata
        self.body = body; self.category_id = category_id
    }
}

// ===== Docs-style lexing (body { … } is a string block) =====
private func docsPolicies() -> BlockPolicyTable {
    BlockPolicyTable(
        predetermined: [
            ["body"]: .init(
                delimiter: .braces,
                options: .init(trimWhitespace: true, unquoteIfWrapped: false, unescapeCommon: false, normalizeNewlines: true)
            )
        ],
        fallback: .init(
            delimiter: .braces,
            options: .init(trimWhitespace: true, unquoteIfWrapped: false, unescapeCommon: false, normalizeNewlines: true)
        )
    )
}

private func makeDocsLexingSets(fieldsAsKeywords: Bool) -> LexingSets {
    let fieldNames = ["article", "label", "hide", "version", "sort", "metadata", "body"]
    let atoms      = ["self", "true", "false"]

    if fieldsAsKeywords {
        return LexingSets(
            keywords: Set(fieldNames + atoms),
            idents: [],
            stringBlockKeywords: ["body"]
        )
    } else {
        // Only keep truly special atoms as keywords; fields come in as identifiers.
        return LexingSets(
            keywords: Set(atoms),
            idents: Set(fieldNames),
            stringBlockKeywords: ["body"]
        )
    }
}

private func makeDocsCursor(_ source: String, sets: LexingSets) -> TokenCursor {
    var opts = LexerOptions()
    opts.emit_whitespace = false
    opts.emit_comments   = false
    opts.emit_newlines   = true
    opts.block_string_policies = docsPolicies()
    var lx = Lexer(source: source, sets: sets, options: opts)
    let (tokens, lines) = lx.collectAllTokensWithLineMap()
    return TokenCursor(tokens, lineMap: lines, filePath: "fixtures/article.hdoc")
}

// ===== DynamicallyParsable conformance =====
extension ArticleDef: DynamicallyParsable {
    public static func parserComponents() -> ParserComponents {
        var pc = ParserComponents.basic()

        // body { ... } → .map(["raw": .string])
        pc.register("bodyPayload") {
            let p: AnyTokenParser<SyntaxNode> =
                TokenParsers.braces(TokenParsers.string())
                .map { s in SyntaxNode.map(["raw": .string(s)]) }
                .trace("bodyPayload")
            return p
        }

        pc.register("boolAtom") {
            let kwTrue  = TokenParsers.keyword(.raw("true")).map { SyntaxNode.atom("true") }
            let kwFalse = TokenParsers.keyword(.raw("false")).map { SyntaxNode.atom("false") }
            let ident   = TokenParsers.identifier().map { SyntaxNode.atom($0) }
            return kwTrue.orElse(kwFalse).orElse(ident).trace("boolAtom")
        }

        pc.register("stringArray") {
            let item = TokenParsers.string().map(SyntaxNode.string)
            return TokenParsers.brackets(separatedList(item: item, sep: .comma))
                .map(SyntaxNode.list)
                .trace("stringArray")
        }

        pc.register("articleHead") {
            let selfString = TokenParsers.keyword(.raw("self")).map { "self" }
            let stringOrId = AnyTokenParser<String> { ctx in
                if case .string(let s)?     = ctx.peek() { var n = ctx; n.advance(); return .success(s, n) }
                if case .identifier(let s)? = ctx.peek() { var n = ctx; n.advance(); return .success(s, n) }
                return .failure(Diagnostic("expected string or identifier"))
            }
            let idOrSelf = selfString.orElse(stringOrId)
            let inner    = idOrSelf.map { SyntaxNode.map(["id": .string($0)]) }
            return optTokenWhere({ if case .keyword("article") = $0 { return true }; return false },
                                 then: TokenParsers.parens(inner))
                .then(AnyTokenParser(Expect(.newline)).many(min: 0))
                .map { iv, _ in iv }
                .trace("articleHead")
        }
        // --- Explicit braced maps used by version/sort/metadata ---
        // Helpers
         @Sendable
        func anyNumericValue() -> AnyTokenParser<SyntaxNode> {
            let intP: AnyTokenParser<SyntaxNode> =
                TokenParsers.number().flatMap { dec in
                    AnyTokenParser<SyntaxNode> { c in
                        let n = NSDecimalNumber(decimal: dec)
                        if dec == Decimal(n.intValue) {
                            return .success(.number(Decimal(n.intValue)), c)
                        } else {
                            return .success(.number(dec), c)
                        }
                    }
                }
            let atomInt: AnyTokenParser<SyntaxNode> =
                TokenParsers.identifier().flatMap { s in
                    AnyTokenParser<SyntaxNode> { c in
                        if let v = Int(s) { return .success(.number(Decimal(v)), c) }
                        return .failure(Diagnostic("expected int atom"))
                    }
                }
            let strInt: AnyTokenParser<SyntaxNode> =
                TokenParsers.string().flatMap { s in
                    AnyTokenParser<SyntaxNode> { c in
                        if let v = Int(s) { return .success(.number(Decimal(v)), c) }
                        return .failure(Diagnostic("expected int string"))
                    }
                }
            return intP.orElse(atomInt).orElse(strInt)
        }

        // version { key (=)? int }  — unknown keys allowed
        pc.register("versionMap") {
            // inner value
            let val   = anyNumericValue()
            let key   = TokenParsers.identifier()
            let pair  = key.then(optEquals(then: val).orElse(val)).map { (k, v) in (k, v) }
            let pairs = separatedList(item: pair, sep: .semicolonOrNewline)

            // NEW: allow leading newlines inside the braces
            let leadingNL = AnyTokenParser(Expect(.newline)).many(min: 0)
            let inner     = leadingNL.then(pairs).map { _, xs in xs }

            return TokenParsers.braces(inner)
                .map { kvs in SyntaxNode.map(Dictionary(uniqueKeysWithValues: kvs)) }
                .trace("versionMap")
        }

        // sort { primacy 90; … } or nested: sort { weights { primacy 10 } }
        pc.register("sortMap") {
            final class _Box<T>: @unchecked Sendable { var value: T! }
            let box = _Box<AnyTokenParser<SyntaxNode>>()

            // helper: { key (=)? value } with leading-NL tolerance
            func mapParser(value: AnyTokenParser<SyntaxNode>) -> AnyTokenParser<SyntaxNode> {
                let key   = TokenParsers.identifier()
                let pair  = key.then(optEquals(then: value).orElse(value)).map { (k, v) in (k, v) }
                let body  = separatedList(item: pair, sep: .semicolonOrNewline)
                let lead  = AnyTokenParser(Expect(.newline)).many(min: 0) // NEW
                let inner = lead.then(body).map { _, xs in xs }           // NEW
                return TokenParsers.braces(inner)
                    .map { kvs in SyntaxNode.map(Dictionary(uniqueKeysWithValues: kvs)) }
            }

            // value := number | map(value)
            let numberValue = anyNumericValue()
            let mapValue    = mapParser(value: AnyTokenParser { c in box.value.parse(c) })
            let valueBody   = numberValue.orElse(mapValue)
            box.value       = valueBody

            return mapParser(value: valueBody).trace("sortMap")
        }

        // metadata { published_at "…"; duration_minutes 8; tags ["a","b"] }
        pc.register("metadataMap") {
            let str   = TokenParsers.string().map(SyntaxNode.string)
            let num   = anyNumericValue()
            let list  = TokenParsers.brackets(
                separatedList(item: TokenParsers.string().map(SyntaxNode.string), sep: .comma)
            ).map(SyntaxNode.list)

            let value = str.orElse(num).orElse(list)
            let key   = TokenParsers.identifier()
            let pair  = key.then(optEquals(then: value).orElse(value)).map { (k, v) in (k, v) }
            let body  = separatedList(item: pair, sep: .semicolonOrNewline)

            // NEW: allow leading newlines inside braces
            let lead  = AnyTokenParser(Expect(.newline)).many(min: 0)
            let inner = lead.then(body).map { _, xs in xs }

            return TokenParsers.braces(inner)
                .map { kvs in SyntaxNode.map(Dictionary(uniqueKeysWithValues: kvs)) }
                .trace("metadataMap")
        }

        return pc
    }

    public static func grammarNode() -> GrammarNode {
        GrammarNode(
            name: "articleDef",
            opener: nil,
            delimiter: .none,
            order: .unordered,
            fields: [
                GrammarField("article", .val("articleHead"), multiplicity: .one),
                GrammarField("label", .val("string"), multiplicity: .optional()),
                GrammarField("hide",  .val("boolAtom"), multiplicity: .optional()),

                // // Accept ints inside version{}; unknown keys ok
                // GrammarField("version",
                //              .map(.val("int"), sep: .semicolonOrNewline, allowUnknownKeys: true),
                //              multiplicity: .optional()),

                // // Accept numbers/ints or nested numeric maps; unknown keys ok
                // GrammarField("sort",
                //              .map(.oneOf([.val("int"), .val("number"),
                //                           .map(.oneOf([.val("int"), .val("number")]))]),
                //                   sep: .semicolonOrNewline, allowUnknownKeys: true),
                //              multiplicity: .optional()),

                // // metadata { published_at "..."; duration_minutes 8; tags ["a","b"] }
                // GrammarField("metadata",
                //              .map(.oneOf([.val("string"), .val("int"), .val("stringArray")]),
                //                   sep: .semicolonOrNewline, allowUnknownKeys: true),
                //              multiplicity: .optional()),

                GrammarField("body", .val("bodyPayload"), multiplicity: .optional()),

                GrammarField("version",  .val("versionMap"),  multiplicity: .optional()),
                GrammarField("sort",     .val("sortMap"),     multiplicity: .optional()),
                GrammarField("metadata", .val("metadataMap"), multiplicity: .optional()),
            ],
            validate: nil
        )
    }

    // public static func makeCursor(for source: String) -> TokenCursor { makeDocsCursor(source) }

    public static func makeCursor(for source: String) -> TokenCursor {
        let sets = makeDocsLexingSets(fieldsAsKeywords: true)
        return makeDocsCursor(source, sets: sets)
    }

    public static func fromSyntax(_ node: SyntaxNode) throws -> Self {
        guard case let .map(m) = node else {
            throw NSError(domain: "ArticleDef", code: 1, userInfo: [NSLocalizedDescriptionKey: "expected map"])
        }
        var declaredId: String? = nil
        if case let .map(hm)? = m["article"], case let .string(s)? = hm["id"] {
            declaredId = (s == "self") ? nil : s
        }
        let label: String? = { if case let .string(s)? = m["label"] { return s }; return nil }()
        let hide: Bool? = {
            if case let .atom(a)? = m["hide"] { return a == "true" ? true : (a == "false" ? false : nil) }
            return nil
        }()

        let version: Semver? = {
            guard case let .map(vm)? = m["version"] else { return nil }
            func int(_ k: String) -> Int? {
                switch vm[k] {
                case .some(.number(let d)): return NSDecimalNumber(decimal: d).intValue
                case .some(.atom(let s)):   return Int(s)
                case .some(.string(let s)): return Int(s)
                default: return nil
                }
            }
            if vm.isEmpty { return nil }
            return Semver(major: int("major"), minor: int("minor"), patch: int("patch"))
        }()

        let sort: SortSpec? = {
            guard case let .map(sm)? = m["sort"] else { return nil }
            func int(_ k: String) -> Int? {
                switch sm[k] {
                case .some(.number(let d)): return NSDecimalNumber(decimal: d).intValue
                case .some(.atom(let s)):   return Int(s)
                case .some(.string(let s)): return Int(s)
                default: return nil
                }
            }
            let weights: SortWeights? = {
                guard case let .map(wm)? = sm["weights"] else { return nil }
                func wi(_ k: String) -> Int? {
                    switch wm[k] {
                    case .some(.number(let d)): return NSDecimalNumber(decimal: d).intValue
                    case .some(.atom(let s)):   return Int(s)
                    case .some(.string(let s)): return Int(s)
                    default: return nil
                    }
                }
                if wm.isEmpty { return nil }
                return SortWeights(
                    primacy: wi("primacy"),
                    relevance: wi("relevance"),
                    engagement: wi("engagement"),
                    quality: wi("quality"),
                    manual: wi("manual")
                )
            }()
            let strategy: String? = {
                if case let .string(s)? = sm["strategy"] { return s }
                if case let .atom(s)?   = sm["strategy"] { return s }
                return nil
            }()
            if sm.isEmpty, weights == nil, strategy == nil { return nil }
            return SortSpec(
                primacy: int("primacy"),
                relevance: int("relevance"),
                engagement: int("engagement"),
                manual: int("manual"),
                weights: weights,
                strategy: strategy
            )
        }()

        let metadata: ArticleMeta? = {
            guard case let .map(mm)? = m["metadata"] else { return nil }
            let published: String? = {
                if case let .string(s)? = mm["published_at"] { return s }
                if case let .atom(s)?   = mm["published_at"] { return s }
                return nil
            }()
            let duration: Int? = {
                switch mm["duration_minutes"] {
                case .some(.number(let d)): return NSDecimalNumber(decimal: d).intValue
                case .some(.atom(let s)):   return Int(s)
                case .some(.string(let s)): return Int(s)
                default: return nil
                }
            }()
            let tags: [String]? = {
                switch mm["tags"] {
                case .some(.list(let xs)):
                    return xs.compactMap {
                        if case let .string(s) = $0 { return s }
                        if case let .atom(s)   = $0 { return s }
                        return nil
                    }
                default: return nil
                }
            }()
            if published == nil, duration == nil, (tags == nil || tags?.isEmpty == true) { return nil }
            return ArticleMeta(published_at: published, duration_minutes: duration, tags: tags)
        }()

        // let body: [BodyNode] = {
        //     if case let .string(s)? = m["body"] { return [.raw(s)] }
        //     return []
        // }()

        // body: [BodyNode]
        let body: [BodyNode] = {
            if case let .string(s)? = m["body"] {           // bare string variant
                return [.raw(s)]
            }
            if case let .map(bm)? = m["body"],              // map { raw: "..." } variant
               case let .string(s)? = bm["raw"] {
                return [.raw(s)]
            }
            return []
        }()

        let slug = declaredId ?? "self"
        return ArticleDef(id: declaredId, slug: slug, label: label, hide: hide,
                          version: version, sort: sort, metadata: metadata, body: body,
                          category_id: nil)
    }
}

// === Helpers ===
private func collapseBlankLines(_ s: String) -> String {
    let pattern = #"\n[ \t]*\n+"#
    return s.replacingOccurrences(of: pattern, with: "\n", options: .regularExpression)
}

// ===== Test =====
@Test
func bin_docs_article_header_and_body_roundtrip() {
    let fixture = #"""
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
            tags = ["basis", "puppy", "zit"]
        }

        body {
            Allows

            Freer textinput
        }
    """#

    // parser prefers newlines as separators, but we collapse excessive blanks for stability
    let cur = ArticleDef.makeCursor(for: collapseBlankLines(fixture))
    let p   = ArticleDef.parser()

    switch p.parse(cur) {
    case .failure(let d):
        Issue.record("parse failed: \(d)")
    case .success(let model, _):
        #expect(model.label == "Hoe Honden Leren")
        #expect(model.hide == true)
        #expect(model.version?.major == 0)
        #expect(model.version?.minor == 1)
        #expect(model.version?.patch == 0)
        #expect(model.sort?.primacy == 90)
        #expect(model.metadata?.duration_minutes == 8)
        #expect(model.metadata?.tags == ["basis","puppy","zit"])
        if case let .raw(s) = model.body.first {
            #expect(s.contains("Allows"))
            #expect(s.contains("Freer textinput"))
        } else {
            Issue.record("missing body.raw")
        }
    }
}
