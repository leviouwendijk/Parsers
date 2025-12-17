import Foundation
import Parsing

extension Prebuilt {
    public struct DomainName: Equatable, Sendable, Hashable, Codable {
        /// Normalized (lowercased ASCII) host, e.g. "hondenmeesters.nl"
        public let rawValue: String

        public init(_ value: String) throws {
            self = try DomainNameParser.parse(value)
        }

        public init(_ value: String?) throws {
            guard let v = value else {
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(v)
        }

        internal init(validated rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public enum DomainNameParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case invalidCharacter(Character, location: SourceLocation?)
        case invalidLabel
        case labelTooLong(max: Int, actual: Int)
        case nameTooLong(max: Int, actual: Int)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Domain cannot be empty"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            case .invalidLabel:
                return "Invalid domain label"
            case .labelTooLong(let max, let actual):
                return "Domain label too long (max \(max), got \(actual))"
            case .nameTooLong(let max, let actual):
                return "Domain name too long (max \(max), got \(actual))"
            }
        }
    }

    public struct DomainNameParser: Parser, Sendable {
        public typealias Output = DomainName

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<DomainName> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parseDomainName(&cur)
                return .success(out, cur)
            } catch let e as DomainNameParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Domain parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> DomainName {
            var cur = Cursor(input)
            let out = try parseDomainName(&cur)

            if cur.peek() != nil {
                throw DomainNameParserError.invalidCharacter(cur.peek()!, location: loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parseDomainName(_ cursor: inout Cursor) throws -> DomainName {
            let start = cursor.mark()
            let input = cursor.input

            // Trim surrounding whitespace (Origin shouldn't have it, but callers might).
            while let ch = cursor.peek(), ch == " " || ch == "\t" || ch == "\n" || ch == "\r" { cursor.advance() }
            let contentStart = cursor.mark()

            // Read until whitespace/end.
            var scalars: [UInt8] = []
            scalars.reserveCapacity(64)

            while let ch = cursor.peek() {
                if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
                    break
                }
                guard let s = ch.unicodeScalars.first, s.isASCII else {
                    throw DomainNameParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                }
                let v = UInt8(s.value)

                // Allowed: a-z A-Z 0-9 . -
                let isAlphaNum =
                    (48...57).contains(v) ||
                    (65...90).contains(v) ||
                    (97...122).contains(v)

                if !(isAlphaNum || v == 46 || v == 45) { // . or -
                    throw DomainNameParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                }

                // Lowercase ASCII (avoid Unicode lowercasing cost)
                scalars.append((65...90).contains(v) ? (v + 32) : v)
                cursor.advance()
            }

            // Strip any trailing whitespace (we'll ignore it)
            while let ch = cursor.peek(), ch == " " || ch == "\t" || ch == "\n" || ch == "\r" { cursor.advance() }

            let length = scalars.count
            if length == 0 { throw DomainNameParserError.empty }
            if length > 253 { throw DomainNameParserError.nameTooLong(max: 253, actual: length) }

            // Validate labels:
            // - labels separated by '.'
            // - each label 1...63
            // - label cannot start/end with '-'
            // - no empty label (so no leading/trailing '.' and no consecutive '..')
            var labelLen = 0
            var labelFirst: UInt8? = nil
            var prev: UInt8? = nil

            func finishLabel() throws {
                guard labelLen > 0 else { throw DomainNameParserError.invalidLabel }
                if labelLen > 63 { throw DomainNameParserError.labelTooLong(max: 63, actual: labelLen) }
                if labelFirst == 45 || prev == 45 { throw DomainNameParserError.invalidLabel } // '-'
            }

            for b in scalars {
                if b == 46 { // '.'
                    try finishLabel()
                    labelLen = 0
                    labelFirst = nil
                    prev = b
                    continue
                }

                if labelLen == 0 {
                    labelFirst = b
                }
                labelLen += 1
                prev = b
            }

            try finishLabel()

            // Disallow trailing dot explicitly (would have created empty label anyway)
            if scalars.last == 46 { throw DomainNameParserError.invalidLabel }

            let normalized = String(decoding: scalars, as: UTF8.self)
            let raw = cursor.slice(from: start)

            // If caller included whitespace, cursor.slice(from:) includes it; we only want the domain.
            // So we use the normalized computed value rather than `raw`.
            _ = raw
            _ = contentStart

            return DomainName(validated: normalized)
        }
    }

    // MARK: - Origin

    public struct Origin: Equatable, Sendable, Hashable, Codable {
        public enum Scheme: String, Sendable, Codable {
            case http
            case https
        }

        public let rawValue: String
        public let scheme: Scheme
        public let host: String              // normalized (lowercased ASCII) host or IP literal
        public let port: Int?                // explicit port if present

        public init(_ value: String) throws {
            self = try OriginParser.parse(value)
        }

        public init(_ value: String?) throws {
            guard let v = value else {
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(v)
        }

        internal init(validatedRaw rawValue: String, scheme: Scheme, host: String, port: Int?) {
            self.rawValue = rawValue
            self.scheme = scheme
            self.host = host
            self.port = port
        }

        /// If the Origin omits port, treat it as the default for scheme.
        public var effectivePort: Int {
            if let port { return port }
            switch scheme {
            case .http:  return 80
            case .https: return 443
            }
        }
    }

    public enum OriginParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case invalidScheme
        case missingSchemeSeparator
        case emptyHost
        case invalidCharacter(Character, location: SourceLocation?)
        case invalidPort
        case invalidIPv6Literal

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Origin cannot be empty"
            case .invalidScheme:
                return "Origin scheme must be http or https"
            case .missingSchemeSeparator:
                return "Origin must contain '://'"
            case .emptyHost:
                return "Origin host cannot be empty"
            case .invalidCharacter(let c, let loc?):
                return "Invalid character '\(c)' at \(loc.line):\(loc.column)"
            case .invalidCharacter(let c, nil):
                return "Invalid character '\(c)'"
            case .invalidPort:
                return "Invalid port"
            case .invalidIPv6Literal:
                return "Invalid IPv6 literal"
            }
        }
    }

    /// Parses `Origin` header values like:
    /// - https://example.com
    /// - http://localhost:5173
    /// - https://sub.example.com:8443
    /// - http://[::1]:8080
    public struct OriginParser: Parser, Sendable {
        public typealias Output = Origin

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<Origin> {
            var cur = cursor
            let start = cur.mark()

            do {
                let out = try Self.parseOrigin(&cur)
                return .success(out, cur)
            } catch let e as OriginParserError {
                let d = Diagnostic(e.localizedDescription, range: cur.range(from: start))
                return .failure(d)
            } catch {
                let d = Diagnostic("Origin parse failed: \(error.localizedDescription)", range: cur.range(from: start))
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> Origin {
            var cur = Cursor(input)
            let out = try parseOrigin(&cur)

            if cur.peek() != nil {
                throw OriginParserError.invalidCharacter(cur.peek()!, location: loc(in: input, offset: cur.offset))
            }

            return out
        }

        private static func parseOrigin(_ cursor: inout Cursor) throws -> Origin {
            let start = cursor.mark()
            let input = cursor.input

            // scheme
            var schemeBytes: [UInt8] = []
            schemeBytes.reserveCapacity(5)

            while let ch = cursor.peek() {
                if ch == ":" { break }
                guard let s = ch.unicodeScalars.first, s.isASCII else {
                    throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                }
                let v = UInt8(s.value)
                schemeBytes.append((65...90).contains(v) ? (v + 32) : v)
                cursor.advance()
            }

            if schemeBytes.isEmpty { throw OriginParserError.invalidScheme }

            let schemeStr = String(decoding: schemeBytes, as: UTF8.self)
            let scheme: Origin.Scheme
            switch schemeStr {
            case "http":  scheme = .http
            case "https": scheme = .https
            default: throw OriginParserError.invalidScheme
            }

            // ://
            guard cursor.peek() == ":" else { throw OriginParserError.missingSchemeSeparator }
            cursor.advance()
            guard cursor.peek() == "/" else { throw OriginParserError.missingSchemeSeparator }
            cursor.advance()
            guard cursor.peek() == "/" else { throw OriginParserError.missingSchemeSeparator }
            cursor.advance()

            // host (domain / ipv4 / [ipv6])
            var hostBytes: [UInt8] = []
            hostBytes.reserveCapacity(64)

            if cursor.peek() == "[" {
                // bracketed IPv6 literal
                cursor.advance()

                var seenEnd = false
                while let ch = cursor.peek() {
                    if ch == "]" {
                        seenEnd = true
                        cursor.advance()
                        break
                    }
                    guard let s = ch.unicodeScalars.first, s.isASCII else {
                        throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                    }
                    let v = UInt8(s.value)
                    // very small allowance for hex + ':' + '.'
                    let isHex =
                        (48...57).contains(v) ||
                        (65...70).contains(v) ||
                        (97...102).contains(v)
                    if !(isHex || v == 58 || v == 46) {
                        throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                    }
                    hostBytes.append((65...90).contains(v) ? (v + 32) : v)
                    cursor.advance()
                }

                if !seenEnd { throw OriginParserError.invalidIPv6Literal }
                if hostBytes.isEmpty { throw OriginParserError.emptyHost }
            } else {
                // read until ':' (port) or end
                while let ch = cursor.peek() {
                    if ch == ":" { break }

                    guard let s = ch.unicodeScalars.first, s.isASCII else {
                        throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                    }
                    let v = UInt8(s.value)

                    // Allow: a-z A-Z 0-9 . -  (domain) plus digits+dot for ipv4
                    let isAlphaNum =
                        (48...57).contains(v) ||
                        (65...90).contains(v) ||
                        (97...122).contains(v)

                    if !(isAlphaNum || v == 46 || v == 45) {
                        throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                    }

                    hostBytes.append((65...90).contains(v) ? (v + 32) : v)
                    cursor.advance()
                }

                if hostBytes.isEmpty { throw OriginParserError.emptyHost }
            }

            let host = String(decoding: hostBytes, as: UTF8.self)

            // optional :port
            var port: Int? = nil
            if cursor.peek() == ":" {
                cursor.advance()

                var portValue = 0
                var digits = 0

                while let ch = cursor.peek() {
                    guard let s = ch.unicodeScalars.first, s.isASCII else {
                        throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                    }
                    let v = s.value
                    guard (48...57).contains(v) else {
                        throw OriginParserError.invalidCharacter(ch, location: loc(in: input, offset: cursor.offset))
                    }

                    portValue = (portValue * 10) + Int(v - 48)
                    digits += 1
                    if digits > 5 { throw OriginParserError.invalidPort } // > 65535
                    cursor.advance()
                }

                guard digits > 0, (1...65535).contains(portValue) else { throw OriginParserError.invalidPort }
                port = portValue
            }

            let raw = cursor.slice(from: start)
            return Origin(validatedRaw: raw, scheme: scheme, host: host, port: port)
        }
    }

    // MARK: - Compiled CORS matcher

    public struct CORSOriginMatcher: Sendable, Hashable {
        public enum HostRule: Sendable, Hashable {
            case exact(DomainName)
            /// Matches foo.base.tld (and optionally base.tld)
            case subdomains(of: DomainName, includeApex: Bool)
            case localhost
            /// Bracketed or unbracketed IPs will be in `Origin.host` without the brackets.
            case ipv4
            case ipv6
        }

        public enum PortRule: Sendable, Hashable {
            case any
            case exact(Int)
            case whitelist(Set<Int>)
        }

        public struct Rule: Sendable, Hashable {
            public let schemes: Set<Origin.Scheme>      // empty = any
            public let host: HostRule
            public let port: PortRule                  // evaluated with Origin.effectivePort

            public init(
                schemes: Set<Origin.Scheme> = [],
                host: HostRule,
                port: PortRule = .any
            ) {
                self.schemes = schemes
                self.host = host
                self.port = port
            }

            public func matches(_ origin: Origin) -> Bool {
                if !schemes.isEmpty, !schemes.contains(origin.scheme) {
                    return false
                }

                let okHost: Bool
                switch host {
                case .localhost:
                    okHost = (origin.host == "localhost") || (origin.host == "127.0.0.1") || (origin.host == "::1")
                case .exact(let d):
                    okHost = (origin.host == d.rawValue)
                case .subdomains(let base, let includeApex):
                    if origin.host == base.rawValue {
                        okHost = includeApex
                    } else {
                        okHost = origin.host.hasSuffix("." + base.rawValue)
                    }
                case .ipv4:
                    okHost = origin.host.split(separator: ".").count == 4 && origin.host.allSatisfy { ch in
                        (ch >= "0" && ch <= "9") || ch == "."
                    }
                case .ipv6:
                    // cheap check: contains ':' (since we normalized to lowercase ASCII)
                    okHost = origin.host.contains(":")
                }

                guard okHost else { return false }

                let p = origin.effectivePort
                switch port {
                case .any:
                    return true
                case .exact(let expected):
                    return p == expected
                case .whitelist(let set):
                    return set.contains(p)
                }
            }
        }

        private let rules: [Rule]

        public init(rules: [Rule]) {
            self.rules = rules
        }

        /// Fast path: returns false if origin can't be parsed.
        public func allows(_ originHeader: String) -> Bool {
            guard let origin = try? OriginParser.parse(originHeader) else { return false }
            return rules.contains(where: { $0.matches(origin) })
        }
    }
}
