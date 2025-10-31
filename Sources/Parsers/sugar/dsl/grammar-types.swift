import Foundation

public indirect enum GValue: Sendable {
    case val(_ name: String)                     // use registered parser by name (e.g., "decimal")
    case node(_ ref: String)                     // reference to another GNode (nesting/recursion)
    case list(_ elem: GValue, sep: GSep = .commaOrNewline)
    case map(_ value: GValue, sep: GSep = .semicolonOrNewline, allowUnknownKeys: Bool = true)
    case oneOf([GValue])                         // alternatives
    case raw(_ p: AnyTokenParser<SyntaxNode>)    // escape hatch

    static func optional(_ inner: GValue, default def: SyntaxNode? = nil) -> GValue {
        .oneOf([inner, .raw(AnyTokenParser { .success(def ?? .list([]), $0) })])
    }
}

public enum GSep: Sendable { case comma, semicolon, newline, commaOrNewline, semicolonOrNewline, none }

// Field multiplicity captures optional/many in one place.
public enum GMultiplicity: Sendable {
    case one
    case optional(defaultValue: SyntaxNode? = nil)
    case many(sep: GSep = .commaOrNewline)
}

public struct GField: Sendable {
    public let name: String
    public let value: GValue
    public let multiplicity: GMultiplicity

    // Back-compat initializers
    public init(_ name: String, _ value: GValue, required: Bool = true, repeated: Bool = false) {
        self.name = name
        self.value = value
        if repeated { self.multiplicity = .many() }
        else { self.multiplicity = required ? .one : .optional(defaultValue: nil) }
    }

    public init(_ name: String, _ value: GValue, multiplicity: GMultiplicity) {
        self.name = name; self.value = value; self.multiplicity = multiplicity
    }
}

public enum GOrder: Sendable { case ordered, unordered }

public struct GNode: Sendable {
    public let name: String
    public let opener: Keyword?          // optional leading keyword, e.g. `entry { ... }`
    public let delimiter: Delim          // (), [], {} around body
    public let order: GOrder
    public let fields: [GField]
    public let validate: (@Sendable ([String: [SyntaxNode]]) -> [Diagnostic])?

    public enum Delim: Sendable { case parens, braces, brackets, none }

    public init(
        name: String,
        opener: Keyword? = nil,
        delimiter: Delim = .braces,
        order: GOrder = .unordered,
        fields: [GField],
        validate: (@Sendable ([String: [SyntaxNode]]) -> [Diagnostic])? = nil
    ) {
        self.name = name; self.opener = opener; self.delimiter = delimiter; self.order = order
        self.fields = fields; self.validate = validate
    }
}

public struct GValidators {
    public static func requireKeys(_ keys: Set<String>) -> (@Sendable ([String: [SyntaxNode]]) -> [Diagnostic]) {
        return { bucket in
            let missing = keys.subtracting(bucket.keys)
            return missing.isEmpty ? [] : [Diagnostic("missing keys: \(missing.joined(separator: ", "))")]
        }
    }
}

public struct Grammar: Sendable {
    public let nodes: [String: GNode]
    public let values: ParserComponents
    public let child: @Sendable () -> AnyTokenParser<SyntaxNode>   // open recursion provider

    public init(nodes: [GNode], values: ParserComponents, child: @escaping @Sendable () -> AnyTokenParser<SyntaxNode>) {
        self.nodes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        self.values = values
        self.child = child
    }
}
