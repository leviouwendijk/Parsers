import Foundation
import Parsing
import Methods

extension Prebuilt {
    public struct HumanNameComponents: Equatable, Sendable, Hashable, Codable {
        public let first: String
        public let middle_names: [String]?
        public let infix: String?
        public let last: String

        public init(
            first: String,
            middle_names: [String]? = nil,
            infix: String? = nil,
            last: String
        ) throws {
            self.first = try Self.parsePart(first, field: "first")
            self.last  = try Self.parsePart(last, field: "last")

            if let m = middle_names {
                let cleaned = try Self.parseParts(m, field: "middle_names")
                self.middle_names = cleaned.isEmpty ? nil : cleaned
            } else {
                self.middle_names = nil
            }

            if let i = Prebuilt.normalizeOptional(infix) {
                self.infix = try Self.parsePart(i, field: "infix")
            } else {
                self.infix = nil
            }
        }

        public init(
            first: String?,
            middle_names: [String]? = nil,
            infix: String? = nil,
            last: String?
        ) throws {
            guard let f = first else { 
                throw RawInputValueError.empty(Self.self) 
            }
            guard let l = last else {
                throw RawInputValueError.empty(Self.self) 
            }
            try self.init(first: f, middle_names: middle_names, infix: infix, last: l)
        }

        public var segments: [String] {
            return
                [first]
                + (middle_names ?? [])
                + (infix.map { [$0] } ?? [])
                + [last]
        }

        public var fullName: HumanFullName {
            // This is already validated/normalized; reuse validated init.
            return HumanFullName(validated: segments.joined(separator: " "))
        }

        private static func parsePart(_ s: String, field: String) throws -> String {
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 1,
                maxLength: 64,
                collapseWhitespace: true,
                allowNewlines: false
            )
            return try NonEmptyText(s, config: cfg).rawValue
        }

        private static func parseParts(_ parts: [String], field: String) throws -> [String] {
            var out: [String] = []
            out.reserveCapacity(parts.count)

            for p in parts {
                let trimmed = Prebuilt.normalizeOptional(p)
                if let trimmed {
                    out.append(try parsePart(trimmed, field: field))
                }
            }

            return out
        }
    }

    public enum HumanNameComponentsParserError: Error, LocalizedError, Sendable, Equatable {
        case tooFewParts(location: SourceLocation?)

        public var errorDescription: String? {
            switch self {
            case .tooFewParts(let loc?):
                return "Name must contain at least first + last at \(loc.line):\(loc.column)"
            case .tooFewParts(nil):
                return "Name must contain at least first + last"
            }
        }
    }

    /// Parses a *single* string into components:
    /// - first = first token
    /// - last  = last token
    /// - middle_names = everything in between (if any)
    /// - infix = nil (cannot infer safely)
    public struct HumanNameComponentsParser: Parser, Sendable {
        public typealias Output = HumanNameComponents

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<HumanNameComponents> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parseComponents(&cur)
                return .success(out, cur)
            } catch let e as HumanNameComponentsParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Name components parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> HumanNameComponents {
            var cur = Cursor(input)
            let out = try parseComponents(&cur)

            if cur.peek() != nil {
                throw HumanNameComponentsParserError.tooFewParts(location: Prebuilt.loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parseComponents(_ cursor: inout Cursor) throws -> HumanNameComponents {
            let input = cursor.input

            // First normalize with the same behavior as full-name (collapse whitespace etc)
            let full = try HumanFullNameParser.parse(input)

            // Consume everything since we parsed from the entire string
            while cursor.peek() != nil { cursor.advance() }

            let tokens = full.rawValue
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty }

            guard tokens.count >= 2 else {
                throw HumanNameComponentsParserError.tooFewParts(location: Prebuilt.loc(in: input, offset: 0))
            }

            let first = tokens.first!
            let last = tokens.last!
            let middle = tokens.count > 2 ? Array(tokens.dropFirst().dropLast()) : nil

            return try HumanNameComponents(
                first: first,
                middle_names: middle,
                infix: nil,
                last: last
            )
        }
    }

    public static func parseOptionalHumanNameComponents(
        first_name: String?,
        middle_names: [String]?,
        infix: String?,
        last_name: String?
    ) throws -> HumanNameComponents? {
        let f_n = normalizeOptional(first_name)
        let m_n = normalizeOptional(middle_names)
        let inf = normalizeOptional(infix)
        let l_n = normalizeOptional(last_name)

        var optionals: [String?] = [
            f_n, inf, l_n
        ]

        m_n.ifNotNil { array in
            optionals.append(contentsOf: array.map {$0} )
        }

        if optionals.allNil {
            return nil
        }

        return try HumanNameComponents(
            first: f_n,
            middle_names: m_n,
            infix: inf,
            last: l_n
        )
    }
}
