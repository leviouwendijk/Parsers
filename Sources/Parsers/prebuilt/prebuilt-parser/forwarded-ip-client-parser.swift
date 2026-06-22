import Foundation

extension Prebuilt {
    public struct ForwardedClientIP: Equatable, Sendable, Hashable, Codable, CustomStringConvertible {
        public let ip: IPAddress

        public var rawValue: String {
            ip.rawValue
        }

        public var description: String {
            rawValue
        }

        public init(
            _ value: String?
        ) throws {
            self = try ForwardedClientIPParser.parse(value)
        }

        internal init(
            ip: IPAddress
        ) {
            self.ip = ip
        }
    }

    public enum ForwardedClientIPParserError: Error, LocalizedError, Sendable, Equatable {
        case missing
        case emptyChain

        public var errorDescription: String? {
            switch self {
            case .missing:
                return "Forwarded client IP header is missing"

            case .emptyChain:
                return "Forwarded client IP chain is empty"
            }
        }
    }

    public struct ForwardedClientIPParser: Sendable {
        public static func parse(
            _ input: String?
        ) throws -> ForwardedClientIP {
            guard let input else {
                throw ForwardedClientIPParserError.missing
            }

            let first = input
                .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let first, !first.isEmpty else {
                throw ForwardedClientIPParserError.emptyChain
            }

            return try ForwardedClientIP(
                ip: IPAddressParser.parse(first)
            )
        }
    }
}
