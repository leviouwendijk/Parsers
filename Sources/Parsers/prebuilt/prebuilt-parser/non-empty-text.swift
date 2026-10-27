import Foundation
import Position
import Parsing
import Primitives

extension Prebuilt {
    public struct NonEmptyText: Invariant, Equatable, Sendable, Hashable, Codable {
        /// Text after the caller's chosen normalization policy, before intrinsic validation.
        public struct Raw: Sendable, Hashable {
            public let value: String

            public init(_ value: String) {
                self.value = value
            }
        }

        public typealias Error = NonEmptyTextParserError

        public let rawValue: String

        /// The intrinsic guarantee is nonblank text; length and normalization are parser policy.
        public init(_ raw: Raw) throws(Error) {
            guard raw.value.contains(where: { !$0.isWhitespace }) else {
                throw .empty
            }
            self.rawValue = raw.value
        }

        /// Retains the original configurable normalization and length-validation behavior.
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
            guard let value else {
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(value, config: config)
        }

        private enum CodingKeys: String, CodingKey {
            case rawValue
        }

        /// Decoding must preserve the intrinsic guarantee without re-normalizing stored text.
        /// Encoding remains synthesized with the existing keyed `rawValue` representation.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawValue = try container.decode(String.self, forKey: .rawValue)
            do {
                try self.init(Raw(rawValue))
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: .rawValue,
                    in: container,
                    debugDescription: error.localizedDescription
                )
            }
        }
    }

    public enum NonEmptyTextParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case tooShort(min: Int, actual: Int)
        case tooLong(max: Int, actual: Int)
        case invalidCharacter(Character, location: Position?)

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
            RawTextParser(config: config)
                .invariant(NonEmptyText.self)
                .tryMap { value in
                    try Self.validateLength(value, config: config)
                    return value
                }
                .parse(cursor)
        }

        public static func parse(_ input: String, config: Configuration = .init()) throws -> NonEmptyText {
            var cursor = Cursor(input)
            let raw = try parseRawText(&cursor, config: config)
            let value = try NonEmptyText(raw)
            try validateLength(value, config: config)
            if let character = cursor.peek() {
                throw NonEmptyTextParserError.invalidCharacter(
                    character,
                    location: Prebuilt.loc(in: input, offset: cursor.offset)
                )
            }
            return value
        }

        private static func validateLength(_ value: NonEmptyText, config: Configuration) throws {
            let count = value.rawValue.count
            if count < config.minLength {
                throw NonEmptyTextParserError.tooShort(min: config.minLength, actual: count)
            }
            if count > config.maxLength {
                throw NonEmptyTextParserError.tooLong(max: config.maxLength, actual: count)
            }
        }

        private struct RawTextParser: Parser, Sendable {
            let config: Configuration

            func parse(_ cursor: Cursor) -> ParseResult<NonEmptyText.Raw> {
                var current = cursor
                let start = current.mark()
                do {
                    return .success(try NonEmptyTextParser.parseRawText(&current, config: config), current)
                } catch let error as NonEmptyTextParserError {
                    return .failure(Diagnostic(error.localizedDescription, range: current.range(from: start)))
                } catch {
                    return .failure(Diagnostic("Text parse failed: \(error.localizedDescription)", range: current.range(from: start)))
                }
            }
        }

        private static func parseRawText(
            _ cursor: inout Cursor,
            config: Configuration
        ) throws -> NonEmptyText.Raw {
            let input = cursor.input
            var output = ""
            output.reserveCapacity(min(256, input.count))

            var sawNonWhitespace = false
            var pendingSpace = false

            func flushPendingSpaceIfNeeded() {
                if config.collapseWhitespace, pendingSpace, sawNonWhitespace, !output.isEmpty {
                    output.append(" ")
                }
                pendingSpace = false
            }

            while let character = cursor.peek() {
                let isNewline = character == "\n" || character == "\r" || character == "\r\n"
                if isNewline && !config.allowNewlines {
                    throw NonEmptyTextParserError.invalidCharacter(
                        character,
                        location: Prebuilt.loc(in: input, offset: cursor.offset)
                    )
                }

                if !isNewline,
                   let scalar = character.unicodeScalars.first,
                   Prebuilt.isControlScalar(scalar) {
                    throw NonEmptyTextParserError.invalidCharacter(
                        character,
                        location: Prebuilt.loc(in: input, offset: cursor.offset)
                    )
                }

                if character.isWhitespace || isNewline {
                    if config.collapseWhitespace {
                        pendingSpace = pendingSpace || sawNonWhitespace
                    } else {
                        output.append(character)
                    }
                    cursor.advance()
                    continue
                }

                flushPendingSpaceIfNeeded()
                output.append(character)
                sawNonWhitespace = true
                cursor.advance()
            }

            return NonEmptyText.Raw(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
