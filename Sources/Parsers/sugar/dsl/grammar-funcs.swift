import Foundation

@inlinable
public func separator(_ s: GSep) -> AnyTokenParser<Void> {
    switch s {
    case .comma:              return AnyTokenParser(Expect(.comma)).map { (_: Token) in () }
    case .semicolon:          return AnyTokenParser(Expect(.semicolon)).map { (_: Token) in () }
    case .newline:            return AnyTokenParser(Expect(.newline)).map { (_: Token) in () }
    case .commaOrNewline:     return AnyTokenParser(Expect(.comma)).orElse(AnyTokenParser(Expect(.newline))).map { (_: Token) in () }
    case .semicolonOrNewline: return AnyTokenParser(Expect(.semicolon)).orElse(AnyTokenParser(Expect(.newline))).map { (_: Token) in () }
    case .none:               return AnyTokenParser { .success((), $0) }
    }
}

@inlinable
public func delimited<T>(_ d: GNode.Delim, body: AnyTokenParser<T>) -> AnyTokenParser<T> {
    switch d {
    case .parens:   return TokenParsers.parens(body)
    case .brackets: return TokenParsers.brackets(body)
    case .braces:   return TokenParsers.braces(body)
    case .none:     return body
    }
}

@inlinable
public func separatedList<T>(item: AnyTokenParser<T>, sep: GSep) -> AnyTokenParser<[T]> {
    let s = separator(sep)
    return item.then(s.optional()).many(min: 0).map { $0.map { $0.0 } }
}

@inlinable
public func chain<T>(_ parts: [AnyTokenParser<T>]) -> AnyTokenParser<[T]> {
    parts.dropFirst().reduce(parts.first!.map { [$0] }) { acc, next in
        acc.then(next).map { $0 + [$1] }
    }
}

@inlinable
public func fold(_ r: GResult) -> SyntaxNode {
    switch r {
    case .atom(let n): return n
    case .list(let xs): return .list(xs)
    case .map(let m): return .map(m)
    case .object(let name, let fields):
        var m: [String: SyntaxNode] = ["_type": .atom(name)]
        for (k, vs) in fields { m[k] = vs.count == 1 ? vs[0] : .list(vs) }
        return .map(m)
    }
}
