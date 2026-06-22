import Foundation

extension Prebuilt {
    public enum CORSOriginPatternError: Error, LocalizedError, Sendable, Equatable {
        case invalidRelativeSubdomain(String, base: String)
        case wildcardCannotExpandToExactOrigins

        public var errorDescription: String? {
            switch self {
            case .invalidRelativeSubdomain(let value, let base):
                return "Invalid relative CORS subdomain '\(value)' for base '\(base)'"

            case .wildcardCannotExpandToExactOrigins:
                return "Wildcard CORS origin patterns cannot be expanded to exact origin strings"
            }
        }
    }

    public struct CORSOriginPattern: Sendable, Hashable {
        private enum Kind: Sendable, Hashable {
            case exactHosts([DomainName])
            case subdomains(base: DomainName, includeApex: Bool)
        }

        private let kind: Kind

        private init(kind: Kind) {
            self.kind = kind
        }

        public static func exact(
            _ host: String,
            includeWWWVariant: Bool = false
        ) throws -> Self {
            let base = try DomainName(host)

            var hosts: [DomainName] = [
                base
            ]

            if includeWWWVariant {
                hosts.append(
                    try DomainName("www.\(base.rawValue)")
                )
            }

            return Self(
                kind: .exactHosts(
                    unique(hosts)
                )
            )
        }

        public static func family(
            base rawBase: String,
            subdomains rawSubdomains: [String] = [],
            includeApex: Bool = true,
            includeWWWVariants: Bool = true
        ) throws -> Self {
            let base = try DomainName(rawBase)

            var hosts: [DomainName] = []

            func appendHost(_ raw: String) throws {
                let host = try DomainName(raw)

                hosts.append(host)

                if includeWWWVariants {
                    hosts.append(
                        try DomainName("www.\(host.rawValue)")
                    )
                }
            }

            if includeApex {
                try appendHost(base.rawValue)
            }

            for rawSubdomain in rawSubdomains {
                let relative = try normalizedRelativeSubdomain(
                    rawSubdomain,
                    base: base
                )

                try appendHost(
                    "\(relative).\(base.rawValue)"
                )
            }

            return Self(
                kind: .exactHosts(
                    unique(hosts)
                )
            )
        }

        public static func subdomains(
            of rawBase: String,
            includeApex: Bool = false
        ) throws -> Self {
            Self(
                kind: .subdomains(
                    base: try DomainName(rawBase),
                    includeApex: includeApex
                )
            )
        }

        public func rules(
            schemes: Set<Origin.Scheme> = [.https],
            port: CORSOriginMatcher.PortRule = .any
        ) -> [CORSOriginMatcher.Rule] {
            switch kind {
            case .exactHosts(let hosts):
                return hosts.map { host in
                    CORSOriginMatcher.Rule(
                        schemes: schemes,
                        host: .exact(host),
                        port: port
                    )
                }

            case .subdomains(let base, let includeApex):
                return [
                    CORSOriginMatcher.Rule(
                        schemes: schemes,
                        host: .subdomains(
                            of: base,
                            includeApex: includeApex
                        ),
                        port: port
                    )
                ]
            }
        }

        public func matcher(
            schemes: Set<Origin.Scheme> = [.https],
            port: CORSOriginMatcher.PortRule = .any
        ) -> CORSOriginMatcher {
            CORSOriginMatcher(
                rules: rules(
                    schemes: schemes,
                    port: port
                )
            )
        }

        public func exactOrigins(
            schemes: [Origin.Scheme] = [.https],
            port: Int? = nil
        ) throws -> [String] {
            guard case .exactHosts(let hosts) = kind else {
                throw CORSOriginPatternError.wildcardCannotExpandToExactOrigins
            }

            return hosts.flatMap { host in
                schemes.map { scheme in
                    Self.originString(
                        scheme: scheme,
                        host: host,
                        port: port
                    )
                }
            }
        }

        private static func normalizedRelativeSubdomain(
            _ raw: String,
            base: DomainName
        ) throws -> String {
            let trimmed = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard
                !trimmed.isEmpty,
                !trimmed.hasPrefix("."),
                !trimmed.hasSuffix("."),
                trimmed != base.rawValue,
                !trimmed.hasSuffix(".\(base.rawValue)")
            else {
                throw CORSOriginPatternError.invalidRelativeSubdomain(
                    raw,
                    base: base.rawValue
                )
            }

            _ = try DomainName(
                "\(trimmed).\(base.rawValue)"
            )

            return trimmed
        }

        private static func originString(
            scheme: Origin.Scheme,
            host: DomainName,
            port: Int?
        ) -> String {
            if let port {
                return "\(scheme.rawValue)://\(host.rawValue):\(port)"
            }

            return "\(scheme.rawValue)://\(host.rawValue)"
        }

        private static func unique(
            _ hosts: [DomainName]
        ) -> [DomainName] {
            var seen: Set<DomainName> = []
            var result: [DomainName] = []

            for host in hosts where seen.insert(host).inserted {
                result.append(host)
            }

            return result
        }
    }
}
