import Foundation
import Parsing

extension Prebuilt {
    public struct PhoneNumber: Equatable, Sendable, Hashable, Codable {
        /// Normalized phone number:
        /// - either "+<digits>" or "<digits>"
        public let rawValue: String

        public init(
            _ value: String
        ) throws {
            self = try PhoneParser.parse(value)
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

    public enum PhoneParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case misplacedPlus(location: SourceLocation?)
        case invalidCharacter(Character, location: SourceLocation?)
        case tooShort(minDigits: Int, actual: Int)
        case tooLong(maxDigits: Int, actual: Int)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Phone number cannot be empty"
            case .misplacedPlus(let loc?):
                return "Misplaced '+' at \(loc.line):\(loc.column)"
            case .misplacedPlus(nil):
                return "Misplaced '+'"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            case .tooShort(let min, let actual):
                return "Phone number is too short (min \(min) digits, got \(actual))"
            case .tooLong(let max, let actual):
                return "Phone number is too long (max \(max) digits, got \(actual))"
            }
        }
    }

    public struct PhoneParser: Parser, Sendable {
        public typealias Output = PhoneNumber

        public struct Configuration: Sendable, Hashable {
            public var minDigits: Int
            public var maxDigits: Int
            public var allowLeadingPlus: Bool
            public var allowInternationalPrefix00: Bool
            public var allowedSeparators: Set<Character>
            public var stopOnExtensionMarker: Bool
            public var extensionMarkers: Set<Character>

            public init(
                minDigits: Int = 8,
                maxDigits: Int = 15,
                allowLeadingPlus: Bool = true,
                allowInternationalPrefix00: Bool = true,
                allowedSeparators: Set<Character> = [" ", "\t", "\n", "-", ".", "(", ")", "/", "\u{00A0}"],
                stopOnExtensionMarker: Bool = true,
                extensionMarkers: Set<Character> = ["x", "X", "#"]
            ) {
                self.minDigits = minDigits
                self.maxDigits = maxDigits
                self.allowLeadingPlus = allowLeadingPlus
                self.allowInternationalPrefix00 = allowInternationalPrefix00
                self.allowedSeparators = allowedSeparators
                self.stopOnExtensionMarker = stopOnExtensionMarker
                self.extensionMarkers = extensionMarkers
            }
        }

        public let config: Configuration

        public init(config: Configuration = .init()) {
            self.config = config
        }

        public func parse(_ cursor: Cursor) -> ParseResult<PhoneNumber> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parsePhone(&cur, config: config)
                return .success(out, cur)
            } catch let e as PhoneParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Phone parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String, config: Configuration = .init()) throws -> PhoneNumber {
            var cur = Cursor(input)
            let out = try parsePhone(&cur, config: config)

            if cur.peek() != nil {
                throw PhoneParserError.invalidCharacter(cur.peek()!, location: loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parsePhone(_ cursor: inout Cursor, config: Configuration) throws -> PhoneNumber {
            let input = cursor.input

            var sawAnyDigit = false
            var hasPlus = false
            var digits: [UInt8] = []
            digits.reserveCapacity(min(32, max(0, config.maxDigits)))

            while let ch = cursor.peek() {
                if isDigit(ch) {
                    sawAnyDigit = true
                    digits.append(digitValue(ch))
                    cursor.advance()
                    continue
                }

                if ch == "+" {
                    if !config.allowLeadingPlus || hasPlus || sawAnyDigit {
                        throw PhoneParserError.misplacedPlus(location: loc(in: input, offset: cursor.offset))
                    }
                    hasPlus = true
                    cursor.advance()
                    continue
                }

                // Allow separators first (including spaces)
                if config.allowedSeparators.contains(ch) {
                    cursor.advance()
                    continue
                }

                // Optional: ignore extension like "x123" or "#123" (and any separators after it)
                if config.stopOnExtensionMarker, config.extensionMarkers.contains(ch) {
                    cursor.advance() // consume marker
                    while let c2 = cursor.peek() {
                        if isDigit(c2) || config.allowedSeparators.contains(c2) {
                            cursor.advance()
                            continue
                        }
                        break
                    }
                    break
                }

                // Now reject control chars
                if let s = ch.unicodeScalars.first, isControlScalar(s) {
                    throw PhoneParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                }

                throw PhoneParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
            }

            if digits.isEmpty {
                throw PhoneParserError.empty
            }

            // Normalize digits to a String
            var digitString = String(bytes: digits.map { $0 + 48 }, encoding: .utf8) ?? ""

            // Optional: normalize leading "00" into "+"
            if !hasPlus, config.allowInternationalPrefix00, digitString.hasPrefix("00"), digitString.count > 2 {
                digitString.removeFirst(2)
                hasPlus = true
            }

            let count = digitString.count
            if count < config.minDigits {
                throw PhoneParserError.tooShort(minDigits: config.minDigits, actual: count)
            }
            if count > config.maxDigits {
                throw PhoneParserError.tooLong(maxDigits: config.maxDigits, actual: count)
            }

            let normalized = hasPlus ? "+" + digitString : digitString
            return PhoneNumber(validated: normalized)
        }

        @inline(__always)
        static func isDigit(_ ch: Character) -> Bool {
            guard let s = ch.unicodeScalars.first, s.isASCII else { return false }
            return (48...57).contains(s.value)
        }

        @inline(__always)
        static func digitValue(_ ch: Character) -> UInt8 {
            UInt8(ch.unicodeScalars.first!.value - 48)
        }

        @inline(__always)
        static func badScalar(_ s: Unicode.Scalar) -> Bool {
            CharacterSet.whitespacesAndNewlines.contains(s) || isControlScalar(s)
        }

        static func isControlScalar(_ s: Unicode.Scalar) -> Bool {
            let v = s.value
            return v < 0x20 || v == 0x7F || (0x80...0x9F).contains(v)
        }

        static func loc(in input: String, offset: Int) -> SourceLocation? {
            var line = 1
            var col = 1
            var i = 0

            for ch in input {
                if i >= offset { break }
                if ch == "\n" {
                    line += 1
                    col = 1
                } else {
                    col += 1
                }
                i += 1
            }

            return SourceLocation(file: nil, line: line, column: col, invocation: nil)
        }
    }
}
