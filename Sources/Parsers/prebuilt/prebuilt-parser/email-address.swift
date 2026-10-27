import Foundation
import Position
import Parsing
import Primitives

extension Prebuilt {
    public struct EmailAddress: Invariant, Equatable, Sendable, Hashable, Codable {
        /// Only the email scanner can construct this lexically checked input.
        /// Semantic completeness is checked when constructing EmailAddress.
        public struct Raw: Sendable, Hashable {
            public let value: String

            fileprivate init(lexicallyValid value: String) {
                self.value = value
            }
        }

        public typealias Error = EmailParserError

        public let rawValue: String

        public init(_ raw: Raw) throws(Error) {
            guard let separator = raw.value.firstIndex(of: "@") else {
                throw .missingAt
            }
            guard separator != raw.value.startIndex else {
                throw .emptyLocalPart
            }
            let domain = raw.value[raw.value.index(after: separator)...]
            guard !domain.isEmpty, domain.contains(".") else {
                throw .emptyDomain
            }
            self.rawValue = raw.value
        }

        public init(_ value: String) throws {
            self = try EmailParser.parse(value)
        }

        public init(_ value: String?) throws {
            guard let value else {
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(value)
        }

        private enum CodingKeys: String, CodingKey {
            case rawValue
        }

        /// Preserve the existing keyed representation, but never trust decoded data.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let value = try container.decode(String.self, forKey: .rawValue)
            do {
                try self.init(value)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: .rawValue,
                    in: container,
                    debugDescription: error.localizedDescription
                )
            }
        }
    }

    public enum EmailParserError: Error, LocalizedError, Sendable, Equatable {
        case emptyLocalPart
        case emptyDomain
        case missingAt
        case invalidCharacter(Character, location: Position?)

        public var errorDescription: String? {
            switch self {
            case .emptyLocalPart:
                return "Local part cannot be empty"
            case .emptyDomain:
                return "Domain part cannot be empty"
            case .missingAt:
                return "Missing '@'"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            }
        }
    }

    public struct EmailParser: Parser, Sendable {
        public typealias Output = EmailAddress

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<EmailAddress> {
            RawEmailParser()
                .invariant(EmailAddress.self)
                .parse(cursor)
        }

        private struct RawEmailParser: Parser, Sendable {
            func parse(_ cursor: Cursor) -> ParseResult<EmailAddress.Raw> {
                var current = cursor
                let start = current.mark()
                do {
                    return .success(try EmailParser.parseEmail(&current), current)
                } catch let error as EmailParserError {
                    return .failure(Diagnostic(
                        error.localizedDescription,
                        range: current.range(from: start),
                        committed: cursor.peek() != nil
                    ))
                } catch {
                    return .failure(Diagnostic(
                        "Email parse failed: \(error.localizedDescription)",
                        range: current.range(from: start),
                        committed: cursor.peek() != nil
                    ))
                }
            }
        }

        // Convenience for validation/normal use.
        public static func parse(_ input: String) throws -> EmailAddress {
            var cursor = Cursor(input)
            let raw = try parseEmail(&cursor)
            if let character = cursor.peek() {
                throw EmailParserError.invalidCharacter(
                    character,
                    location: loc(in: input, offset: cursor.offset)
                )
            }
            return try EmailAddress(raw)
        }

        private static func parseEmail(_ cursor: inout Cursor) throws -> EmailAddress.Raw {
            let start = cursor.mark()
            let input = cursor.input

            enum Phase { case local, domain }
            var phase: Phase = .local

            var localLength = 0
            var localLastWasDot = false

            var domainLength = 0
            var labelLength = 0
            var labelLastWasHyphen = false

            func finishLabelIfNeeded(at offset: Int) throws {
                // Called on '.' in domain and at end of input.
                if labelLength == 0 {
                    throw EmailParserError.emptyDomain
                }
                if labelLastWasHyphen {
                    throw EmailParserError.invalidCharacter("-", location: loc(in: input, offset: offset))
                }
            }

            while let ch = cursor.peek() {
                if let s = ch.unicodeScalars.first, badScalar(s) {
                    throw invalid(ch, input: input, offset: cursor.offset)
                }

                switch phase {
                case .local:
                    if ch == "@" {
                        if localLength == 0 { throw EmailParserError.emptyLocalPart }
                        if localLastWasDot {
                            throw EmailParserError.invalidCharacter(".", location: loc(in: input, offset: cursor.offset - 1))
                        }
                        phase = .domain
                        cursor.advance()
                        continue
                    }

                    if !isAllowedLocal(ch) {
                        throw invalid(ch, input: input, offset: cursor.offset)
                    }

                    if ch == "." {
                        if localLength == 0 || localLastWasDot {
                            throw invalid(ch, input: input, offset: cursor.offset)
                        }
                        localLastWasDot = true
                    } else {
                        localLastWasDot = false
                    }

                    localLength += 1
                    cursor.advance()

                case .domain:
                    // Must be ASCII host-ish domain for this "simple" parser.
                    guard let s = ch.unicodeScalars.first, s.isASCII else {
                        throw invalid(ch, input: input, offset: cursor.offset)
                    }

                    if ch == "@" {
                        throw invalid(ch, input: input, offset: cursor.offset)
                    }

                    if ch == "." {
                        if domainLength == 0 {
                            throw invalid(ch, input: input, offset: cursor.offset)
                        }

                        try finishLabelIfNeeded(at: max(0, cursor.offset - 1))

                        labelLength = 0
                        labelLastWasHyphen = false

                        domainLength += 1
                        cursor.advance()
                        continue
                    }

                    if ch == "-" {
                        // label cannot start with '-'
                        if labelLength == 0 {
                            throw invalid(ch, input: input, offset: cursor.offset)
                        }
                        labelLastWasHyphen = true

                        labelLength += 1
                        domainLength += 1
                        cursor.advance()
                        continue
                    }

                    // a-z A-Z 0-9 only (simple)
                    let v = s.value
                    let isAlphaNum =
                        (48...57).contains(v) ||
                        (65...90).contains(v) ||
                        (97...122).contains(v)

                    if !isAlphaNum {
                        throw invalid(ch, input: input, offset: cursor.offset)
                    }

                    labelLastWasHyphen = false
                    labelLength += 1
                    domainLength += 1
                    cursor.advance()
                }
            }

            // Preserve the scanner's precise offending-character location.
            // Missing '@', empty domains, and missing domain dots are intrinsic
            // completeness checks performed by EmailAddress.init(_ raw:).
            if phase == .domain, domainLength > 0 {
                try finishLabelIfNeeded(at: max(0, cursor.offset - 1))
            }

            return EmailAddress.Raw(lexicallyValid: String(cursor.slice(from: start)))
        }

        static func isAllowedLocal(_ ch: Character) -> Bool {
            guard let s = ch.unicodeScalars.first, s.isASCII else { return false }
            let v = s.value

            // a-z A-Z 0-9
            if (48...57).contains(v) || (65...90).contains(v) || (97...122).contains(v) {
                return true
            }

            // RFC-ish “atext” subset + dot (we handle dot rules elsewhere)
            switch ch {
            case "!", "#", "$", "%", "&", "'", "*", "+", "-", "/", "=", "?", "^", "_", "`", "{", "|", "}", "~", ".":
                return true
            default:
                return false
            }
        }
    }
}
