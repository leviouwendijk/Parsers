import Foundation

// Parse result on token streams
public enum TokenParseResult<T: Sendable> {
    case success(T, TokenCursor)
    case failure(Diagnostic)
}

extension TokenParseResult: Sendable {}

// Token parser protocol
public protocol TokenParser<Output>: Sendable {
    associatedtype Output: Sendable
    func parse(_ cursor: TokenCursor) -> TokenParseResult<Output>
}

// Type-erased token parser
public struct AnyTokenParser<Output: Sendable>: TokenParser, Sendable {
    private let _parse: @Sendable (TokenCursor) -> TokenParseResult<Output>
    public init<P: TokenParser>(_ p: P) where P.Output == Output { _parse = { p.parse($0) } }
    public init(_ parse: @Sendable @escaping (TokenCursor) -> TokenParseResult<Output>) { _parse = parse }
    public func parse(_ c: TokenCursor) -> TokenParseResult<Output> { _parse(c) }
}

// Combinators
public extension TokenParser {
    @inlinable
    func map<U>(_ f: @Sendable @escaping (Output) -> U) -> AnyTokenParser<U> {
        AnyTokenParser<U> { c in
            switch self.parse(c) {
            case .success(let o, let next): return .success(f(o), next)
            case .failure(let d):           return .failure(d)
            }
        }
    }

    @inlinable
    func flatMap<U>(_ f: @Sendable @escaping (Output) -> any TokenParser<U>) -> AnyTokenParser<U> {
        let a = AnyTokenParser(self)
        return AnyTokenParser<U> { c in
            switch a.parse(c) {
            case .failure(let d):           return .failure(d)
            case .success(let o, let next): return AnyTokenParser(f(o)).parse(next)
            }
        }
    }

    @inlinable
    func orElse(_ other: any TokenParser<Output>) -> AnyTokenParser<Output> {
        let a = AnyTokenParser(self), b = AnyTokenParser(other)
        return AnyTokenParser<Output> { c in
            switch a.parse(c) {
            case .success: return a.parse(c)
            case .failure: return b.parse(c)
            }
        }
    }

    @inlinable
    func optional() -> AnyTokenParser<Output?> {
        AnyTokenParser<Output?> { c in
            switch self.parse(c) {
            case .success(let o, let next): return .success(o, next)
            case .failure:                  return .success(nil, c)
            }
        }
    }

    @inlinable
    func many(min: Int = 0) -> AnyTokenParser<[Output]> {
        AnyTokenParser<[Output]> { c in
            var cur = c, acc: [Output] = []
            while true {
                switch self.parse(cur) {
                case .success(let o, let next): acc.append(o); cur = next
                case .failure:
                    return acc.count >= min
                    ? .success(acc, cur)
                    : .failure(Diagnostic("expected at least \(min) occurrence(s)"))
                }
            }
        }
    }

    @inlinable
    func withBacktracking() -> AnyTokenParser<Output> {
        AnyTokenParser<Output> { c in
            let m = c.mark()
            switch self.parse(c) {
            case .success(let o, let next): return .success(o, next)
            case .failure(let d):
                var r = c; r.restore(m)
                return .failure(Diagnostic(d.message, severity: d.severity, range: d.range))
            }
        }
    }
}
