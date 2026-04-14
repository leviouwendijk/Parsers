import Foundation
import Position
import Parsing

extension Prebuilt {
    public struct EmailAddress: Equatable, Sendable, Hashable, Codable {
        public let rawValue: String

        public init(
            _ value: String
        ) throws {
            self = try EmailParser.parse(value)
        }

        public init(
            _ value: String?
        ) throws {
            guard let v = value else { 
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(v)
        }

        internal init(validated rawValue: String) {
            self.rawValue = rawValue
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
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parseEmail(&cur)
                return .success(out, cur)
            } catch let e as EmailParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Email parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        // Convenience for validation/normal use
        public static func parse(_ input: String) throws -> EmailAddress {
            var cur = Cursor(input)
            let out = try parseEmail(&cur)

            // ensure full consumption
            if cur.peek() != nil {
                throw EmailParserError.invalidCharacter(cur.peek()!, location: loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parseEmail(_ cursor: inout Cursor) throws -> EmailAddress {
            let start = cursor.mark()
            let input = cursor.input

            enum Phase { case local, domain }
            var phase: Phase = .local

            var localLength = 0
            var localLastWasDot = false

            var domainLength = 0
            var domainHasDot = false
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

                        domainHasDot = true
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

            // Final validations
            if phase == .local { throw EmailParserError.missingAt }
            if localLength == 0 { throw EmailParserError.emptyLocalPart }
            if domainLength == 0 { throw EmailParserError.emptyDomain }

            // Domain cannot end with '.' or '-' and must have at least one dot
            let lastOffset = max(0, cursor.offset - 1)
            try finishLabelIfNeeded(at: lastOffset)
            if !domainHasDot { throw EmailParserError.emptyDomain }

            let raw = cursor.slice(from: start)
            return EmailAddress(validated: raw)
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
