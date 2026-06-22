import Foundation

extension Prebuilt {
    public struct IPAddress: Equatable, Sendable, Hashable, Codable, CustomStringConvertible {
        public enum Kind: String, Sendable, Codable {
            case ipv4
            case ipv6
        }

        public let rawValue: String
        public let kind: Kind

        public var description: String {
            rawValue
        }

        public init(
            _ value: String
        ) throws {
            self = try IPAddressParser.parse(value)
        }

        internal init(
            parsed rawValue: String,
            kind: Kind
        ) {
            self.rawValue = rawValue
            self.kind = kind
        }
    }

    public enum IPAddressParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case invalidIPAddress(String)
        case unspecifiedIPAddress(String)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "IP address cannot be empty"

            case .invalidIPAddress(let value):
                return "Invalid IP address '\(value)'"

            case .unspecifiedIPAddress(let value):
                return "Unspecified IP address is not allowed: '\(value)'"
            }
        }
    }

    public struct IPAddressParser: Sendable {
        public struct Configuration: Sendable, Hashable {
            public var allowUnspecified: Bool

            public init(
                allowUnspecified: Bool = false
            ) {
                self.allowUnspecified = allowUnspecified
            }
        }

        public static func parse(
            _ input: String,
            config: Configuration = .init()
        ) throws -> IPAddress {
            let raw = input.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !raw.isEmpty else {
                throw IPAddressParserError.empty
            }

            if let ipv4 = try? parseIPv4(raw, config: config) {
                return ipv4
            }

            if raw.contains(":") {
                return try parseIPv6(raw, config: config)
            }

            throw IPAddressParserError.invalidIPAddress(raw)
        }

        private static func parseIPv4(
            _ raw: String,
            config: Configuration
        ) throws -> IPAddress {
            let parts = raw.split(
                separator: ".",
                omittingEmptySubsequences: false
            )

            guard parts.count == 4 else {
                throw IPAddressParserError.invalidIPAddress(raw)
            }

            var normalized: [String] = []
            normalized.reserveCapacity(4)

            for part in parts {
                let octet = try Prebuilt.BoundedIntegerParser
                    .parse(String(part), range: 0...255)
                    .rawValue

                normalized.append(String(octet))
            }

            let value = normalized.joined(separator: ".")

            if !config.allowUnspecified, value == "0.0.0.0" {
                throw IPAddressParserError.unspecifiedIPAddress(value)
            }

            return IPAddress(
                parsed: value,
                kind: .ipv4
            )
        }

        private static func parseIPv6(
            _ raw: String,
            config: Configuration
        ) throws -> IPAddress {
            let value = raw.lowercased()

            guard value.contains(":") else {
                throw IPAddressParserError.invalidIPAddress(raw)
            }

            let allowed = CharacterSet(
                charactersIn: "0123456789abcdef:"
            )

            guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                throw IPAddressParserError.invalidIPAddress(raw)
            }

            guard value != "::" || config.allowUnspecified else {
                throw IPAddressParserError.unspecifiedIPAddress(value)
            }

            return IPAddress(
                parsed: value,
                kind: .ipv6
            )
        }
    }
}
