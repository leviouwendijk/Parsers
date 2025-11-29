import Foundation

extension Prebuilt {
    public struct Honeypot: Equatable, Sendable, Hashable {
        public init(_ value: String) throws {
            _ = try HoneypotParser.parse(value)
        }

        internal init(validated: Void = ()) {}
    }

    public enum HoneypotParserError: Error, LocalizedError, Sendable, Equatable {
        case mustBeEmpty

        public var errorDescription: String? {
            switch self {
            case .mustBeEmpty:
                return "Honeypot field must be empty"
            }
        }
    }

    public struct HoneypotParser: Parser, Sendable {
        public typealias Output = Honeypot

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<Honeypot> {
            var cur = cursor
            let start = cur.mark()

            do {
                _ = try Self.parseHoneypot(&cur)
                return .success(Honeypot(validated: ()), cur)
            } catch let e as HoneypotParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Honeypot parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> Honeypot {
            var cur = Cursor(input)
            _ = try parseHoneypot(&cur)
            if cur.peek() != nil {
                throw HoneypotParserError.mustBeEmpty
            }
            return Honeypot(validated: ())
        }

        private static func parseHoneypot(_ cursor: inout Cursor) throws {
            var sawNonWS = false

            while let ch = cursor.peek() {
                if let s = ch.unicodeScalars.first, Prebuilt.isControlScalar(s) {
                    throw HoneypotParserError.mustBeEmpty
                }

                if !(ch.isWhitespace || ch == "\n" || ch == "\r") {
                    sawNonWS = true
                    break
                }

                cursor.advance()
            }

            if sawNonWS {
                throw HoneypotParserError.mustBeEmpty
            }
        }
    }
}
