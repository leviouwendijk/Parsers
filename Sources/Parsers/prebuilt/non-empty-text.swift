import Foundation

extension Prebuilt {
    public struct NonEmptyText: Equatable, Sendable, Hashable, Codable {
        public let rawValue: String

        public init(
            _ value: String,
            config: NonEmptyTextParser.Configuration = .init()
        ) throws {
            self = try NonEmptyTextParser.parse(value, config: config)
        }

        public init(
            _ value: String?,
            config: NonEmptyTextParser.Configuration = .init()
        ) throws {
            guard let v = value else { 
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(v, config: config)
        }

        internal init(validated rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public enum NonEmptyTextParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case tooShort(min: Int, actual: Int)
        case tooLong(max: Int, actual: Int)
        case invalidCharacter(Character, location: SourceLocation?)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Text cannot be empty"
            case .tooShort(let min, let actual):
                return "Text is too short (min \(min), got \(actual))"
            case .tooLong(let max, let actual):
                return "Text is too long (max \(max), got \(actual))"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            }
        }
    }

    public struct NonEmptyTextParser: Parser, Sendable {
        public typealias Output = NonEmptyText

        public struct Configuration: Sendable, Hashable {
            public var minLength: Int
            public var maxLength: Int
            public var collapseWhitespace: Bool
            public var allowNewlines: Bool

            public init(
                minLength: Int = 1,
                maxLength: Int = 10_000,
                collapseWhitespace: Bool = true,
                allowNewlines: Bool = true
            ) {
                self.minLength = minLength
                self.maxLength = maxLength
                self.collapseWhitespace = collapseWhitespace
                self.allowNewlines = allowNewlines
            }
        }

        public let config: Configuration

        public init(config: Configuration = .init()) {
            self.config = config
        }

        public func parse(_ cursor: Cursor) -> ParseResult<NonEmptyText> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parseText(&cur, config: config)
                return .success(out, cur)
            } catch let e as NonEmptyTextParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Text parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String, config: Configuration = .init()) throws -> NonEmptyText {
            var cur = Cursor(input)
            let out = try parseText(&cur, config: config)

            if cur.peek() != nil {
                throw NonEmptyTextParserError.invalidCharacter(cur.peek()!, location: Prebuilt.loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parseText(_ cursor: inout Cursor, config: Configuration) throws -> NonEmptyText {
            let input = cursor.input
            let start = cursor.mark()

            var out = ""
            out.reserveCapacity(min(256, input.count))

            var sawNonWS = false
            var pendingSpace = false

            func flushPendingSpaceIfNeeded() {
                if config.collapseWhitespace, pendingSpace, sawNonWS, !out.isEmpty {
                    out.append(" ")
                }
                pendingSpace = false
            }

            while let ch = cursor.peek() {
                if let s = ch.unicodeScalars.first, Prebuilt.isControlScalar(s) {
                    throw NonEmptyTextParserError.invalidCharacter(ch, location: Prebuilt.loc(in: input, offset: cursor.offset))
                }

                if ch == "\n" || ch == "\r" {
                    if !config.allowNewlines {
                        throw NonEmptyTextParserError.invalidCharacter(ch, location: Prebuilt.loc(in: input, offset: cursor.offset))
                    }
                }

                if ch.isWhitespace || ch == "\n" || ch == "\r" {
                    if config.collapseWhitespace {
                        pendingSpace = pendingSpace || sawNonWS
                    } else {
                        out.append(ch)
                    }
                    cursor.advance()
                    continue
                }

                flushPendingSpaceIfNeeded()
                out.append(ch)
                sawNonWS = true
                cursor.advance()
            }

            out = out.trimmingCharacters(in: .whitespacesAndNewlines)
            let len = out.count

            if len == 0 { throw NonEmptyTextParserError.empty }
            if len < config.minLength { throw NonEmptyTextParserError.tooShort(min: config.minLength, actual: len) }
            if len > config.maxLength { throw NonEmptyTextParserError.tooLong(max: config.maxLength, actual: len) }

            _ = cursor.slice(from: start) // consumed slice (for composition semantics); output is normalized
            return NonEmptyText(validated: out)
        }
    }
}
