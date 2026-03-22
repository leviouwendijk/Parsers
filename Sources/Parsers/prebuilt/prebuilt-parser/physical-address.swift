import Foundation
import Parsing
import Methods

extension Prebuilt {
    public struct PostalCodeNL: Equatable, Sendable, Hashable {
        /// Normalized as "1234AB" (no space)
        public let rawValue: String

        public init(_ value: String) throws {
            self = try PostalCodeNLParser.parse(value)
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

        public var formatted: String {
            // "1234AB" -> "1234 AB"
            guard rawValue.count == 6 else { return rawValue }
            let i = rawValue.index(rawValue.startIndex, offsetBy: 4)
            return "\(rawValue[..<i]) \(rawValue[i...])"
        }
    }

    public enum PostalCodeNLParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case invalidFormat(location: SourceLocation?)
        case invalidCharacter(Character, location: SourceLocation?)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Postal code cannot be empty"
            case .invalidFormat(let loc?):
                return "Invalid postal code format at \(loc.line):\(loc.column)"
            case .invalidFormat(nil):
                return "Invalid postal code format"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            }
        }
    }

    public struct PostalCodeNLParser: Parser, Sendable {
        public typealias Output = PostalCodeNL

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<PostalCodeNL> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parsePostalCode(&cur)
                return .success(out, cur)
            } catch let e as PostalCodeNLParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Postal code parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> PostalCodeNL {
            var cur = Cursor(input)
            let out = try parsePostalCode(&cur)

            if cur.peek() != nil {
                throw PostalCodeNLParserError.invalidCharacter(cur.peek()!, location: Prebuilt.loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parsePostalCode(_ cursor: inout Cursor) throws -> PostalCodeNL {
            let input = cursor.input
            let start = cursor.mark()

            // Normalize by skipping leading/trailing whitespace in the cursor stream
            while let ch = cursor.peek(), ch.isWhitespace || ch == "\n" || ch == "\r" {
                cursor.advance()
            }

            @inline(__always)
            func invalidFormat() -> PostalCodeNLParserError {
                .invalidFormat(location: Prebuilt.loc(in: input, offset: cursor.offset))
            }

            // 4 digits
            var digits: [UInt8] = []
            digits.reserveCapacity(4)

            for _ in 0..<4 {
                guard let ch = cursor.peek() else { throw invalidFormat() }
                guard let s = ch.unicodeScalars.first, s.isASCII else {
                    throw PostalCodeNLParserError.invalidCharacter(ch, location: Prebuilt.loc(in: input, offset: cursor.offset))
                }
                let v = s.value
                guard (48...57).contains(v) else {
                    throw PostalCodeNLParserError.invalidCharacter(ch, location: Prebuilt.loc(in: input, offset: cursor.offset))
                }
                digits.append(UInt8(v - 48))
                cursor.advance()
            }

            if digits.first == 0 {
                throw invalidFormat()
            }

            while let ch = cursor.peek(), ch == " " || ch == "\t" || ch == "\u{00A0}" {
                cursor.advance()
            }

            // 2 letters
            var letters: [UInt8] = []
            letters.reserveCapacity(2)

            for _ in 0..<2 {
                guard let ch = cursor.peek() else { throw invalidFormat() }
                guard let s = ch.unicodeScalars.first, s.isASCII else {
                    throw PostalCodeNLParserError.invalidCharacter(ch, location: Prebuilt.loc(in: input, offset: cursor.offset))
                }
                var v = s.value
                if (97...122).contains(v) { v = v - 32 }
                guard (65...90).contains(v) else {
                    throw PostalCodeNLParserError.invalidCharacter(ch, location: Prebuilt.loc(in: input, offset: cursor.offset))
                }
                letters.append(UInt8(v))
                cursor.advance()
            }

            while let ch = cursor.peek(), ch.isWhitespace || ch == "\n" || ch == "\r" {
                cursor.advance()
            }

            let normalized =
                "\(digits[0])\(digits[1])\(digits[2])\(digits[3])" +
                (String(bytes: letters, encoding: .utf8) ?? "")

            _ = cursor.slice(from: start)
            return PostalCodeNL(validated: normalized)
        }
    }

    // MARK: - HouseNumber (NL-practical, not perfect)
    public struct HouseNumber: Equatable, Sendable, Hashable {
        /// Normalized, spaces removed, letters uppercased (e.g. "12A", "12-1")
        public let rawValue: String

        public init(_ value: String) throws {
            self = try HouseNumberParser.parse(value)
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

    public enum HouseNumberParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case invalidFormat(location: SourceLocation?)
        case invalidCharacter(Character, location: SourceLocation?)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "House number cannot be empty"
            case .invalidFormat(let loc?):
                return "Invalid house number format at \(loc.line):\(loc.column)"
            case .invalidFormat(nil):
                return "Invalid house number format"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            }
        }
    }

    public struct HouseNumberParser: Parser, Sendable {
        public typealias Output = HouseNumber

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<HouseNumber> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parseHouseNumber(&cur)
                return .success(out, cur)
            } catch let e as HouseNumberParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("House number parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> HouseNumber {
            var cur = Cursor(input)
            let out = try parseHouseNumber(&cur)

            if cur.peek() != nil {
                throw HouseNumberParserError.invalidCharacter(cur.peek()!, location: Prebuilt.loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parseHouseNumber(_ cursor: inout Cursor) throws -> HouseNumber {
            let input = cursor.input
            let start = cursor.mark()

            // trim leading whitespace
            while let ch = cursor.peek(), ch.isWhitespace || ch == "\n" || ch == "\r" {
                cursor.advance()
            }

            func locNow() -> SourceLocation? {
                Prebuilt.loc(in: input, offset: cursor.offset)
            }

            // at least 1 digit (up to 5 digits)
            var digits: [UInt8] = []
            digits.reserveCapacity(5)

            while let ch = cursor.peek(),
                  let s = ch.unicodeScalars.first,
                  s.isASCII,
                  (48...57).contains(s.value),
                  digits.count < 5
            {
                digits.append(UInt8(s.value - 48))
                cursor.advance()
            }

            if digits.isEmpty {
                throw HouseNumberParserError.empty
            }

            // optional whitespace between number and suffix -> removed in normalized value
            while let ch = cursor.peek(), ch == " " || ch == "\t" || ch == "\u{00A0}" {
                cursor.advance()
            }

            // suffix: allow letters/digits and a couple common separators, max 8 chars
            var suffix = ""
            suffix.reserveCapacity(8)

            while let ch = cursor.peek() {
                if ch.isWhitespace || ch == "\n" || ch == "\r" {
                    cursor.advance()
                    continue
                }

                guard let s = ch.unicodeScalars.first, s.isASCII else {
                    throw HouseNumberParserError.invalidCharacter(ch, location: locNow())
                }

                let v = s.value
                let isDigit = (48...57).contains(v)
                let isUpper = (65...90).contains(v)
                let isLower = (97...122).contains(v)
                let isSep = ch == "-" || ch == "/"  // allow "12-1", "12/1"

                if isDigit || isUpper || isLower || isSep {
                    if suffix.count >= 8 {
                        throw HouseNumberParserError.invalidFormat(location: locNow())
                    }
                    if isLower {
                        let upper = Unicode.Scalar(v - 32)!
                        suffix.append(Character(upper))
                    } else {
                        suffix.append(ch)
                    }
                    cursor.advance()
                    continue
                }

                throw HouseNumberParserError.invalidCharacter(ch, location: locNow())
            }

            // Build normalized string
            let numberPart = digits.map { String($0) }.joined()
            let normalized = numberPart + suffix

            _ = cursor.slice(from: start)
            return HouseNumber(validated: normalized)
        }
    }

    // MARK: - StreetName / PlaceName (thin NonEmptyText wrappers)

    public struct StreetName: Equatable, Sendable, Hashable {
        public let rawValue: String

        public init(_ value: String) throws {
            // collapse whitespace, disallow newlines, small max
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 2,
                maxLength: 128,
                collapseWhitespace: true,
                allowNewlines: false
            )
            self.rawValue = try NonEmptyText(value, config: cfg).rawValue
        }
    }

    public struct PlaceName: Equatable, Sendable, Hashable {
        public let rawValue: String

        public init(_ value: String) throws {
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 2,
                maxLength: 128,
                collapseWhitespace: true,
                allowNewlines: false
            )
            self.rawValue = try NonEmptyText(value, config: cfg).rawValue
        }
    }

    // MARK: - PhysicalAddress (components)

    public struct PhysicalAddress: Equatable, Sendable, Hashable {
        public let postalCode: PostalCodeNL
        public let houseNumber: HouseNumber
        public let street: StreetName?
        public let place: PlaceName?

        public init(
            postalCode: String,
            houseNumber: String,
            street: String? = nil,
            place: String? = nil
        ) throws {
            self.postalCode = try PostalCodeNL(postalCode)
            self.houseNumber = try HouseNumber(houseNumber)

            if let s = Prebuilt.normalizeOptional(street) {
                self.street = try StreetName(s)
            } else {
                self.street = nil
            }

            if let p = Prebuilt.normalizeOptional(place) {
                self.place = try PlaceName(p)
            } else {
                self.place = nil
            }
        }

        public init(
            postalCode: String?,
            houseNumber: String?,
            street: String? = nil,
            place: String? = nil
        ) throws {
            self.postalCode = try PostalCodeNL(postalCode)
            self.houseNumber = try HouseNumber(houseNumber)

            if let s = Prebuilt.normalizeOptional(street) {
                self.street = try StreetName(s)
            } else {
                self.street = nil
            }

            if let p = Prebuilt.normalizeOptional(place) {
                self.place = try PlaceName(p)
            } else {
                self.place = nil
            }
        }

        public var singleLine: String {
            var parts: [String] = []
            parts.append("\(postalCode.formatted) \(houseNumber.rawValue)")
            if let street { parts.append(street.rawValue) }
            if let place { parts.append(place.rawValue) }
            return parts.joined(separator: ", ")
        }
    }

    public enum PhysicalAddressError: Error, LocalizedError, Sendable, Equatable {
        case incomplete(missing: [String])

        public var errorDescription: String? {
            switch self {
            case .incomplete(let missing):
                return "Address is incomplete (missing: \(missing.joined(separator: ", ")))"
            }
        }
    }

    /// Helper for optional address blocks:
    /// - returns nil if all address fields are empty/nil
    /// - throws if partially provided (e.g. postcode but no huisnummer)
    public static func parseOptionalPhysicalAddress(
        postcode: String?,
        huisnummer: String?,
        straatnaam: String?,
        place: String?
    ) throws -> PhysicalAddress? {
        let pc = normalizeOptional(postcode)
        let hn = normalizeOptional(huisnummer)
        let st = normalizeOptional(straatnaam)
        let pl = normalizeOptional(place)

        let optionals: [String?] = [
            pc,
            hn,
            st,
            pl
        ]

        if optionals.allNil {
            return nil
        }

        return try PhysicalAddress(
            postalCode: pc,
            houseNumber: hn,
            street: st,
            place: pl
        )
    }
}
