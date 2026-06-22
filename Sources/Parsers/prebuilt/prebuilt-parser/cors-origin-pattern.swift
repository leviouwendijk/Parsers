import Foundation

extension Prebuilt {
    public enum CORSOriginPatternError: Error, LocalizedError, Sendable {
        case invalidHost(String, Error)

        public var errorDescription: String? {
            switch self {
            case .invalidHost(let host, let error):
                return "Invalid CORS origin host pattern '\(host)': \(error.localizedDescription)"
            }
        }
    }

    public struct CORSOriginPattern: Sendable, Hashable {
        public enum Kind: Sendable, Hashable {
            case exactHosts([DomainName])
            case subdomains(base: DomainName, includeApex: Bool)
        }

        public let kind: Kind

        public init(
            kind: Kind
        ) {
            self.kind = kind
        }

        public static func exact(
            _ host: String,
            includeWWWVariant: Bool = false
        ) throws -> Self {
            var hosts: [DomainName] = [
                try parseHost(host)
            ]

            if includeWWWVariant {
                hosts.append(
                    try parseHost(
                        "www.\(hosts[0].rawValue)"
                    )
                )
            }

            return .init(
                kind: .exactHosts(
                    unique(hosts)
                )
            )
        }

        public static func family(
            base: String,
            subdomains: [String] = [],
            includeApex: Bool = true,
            variantPrefixes: [String] = [],
            includeWWWVariants: Bool = false,
            includeVariantCombinations: Bool = true,
            includeVariantPermutations: Bool = true
        ) throws -> Self {
            let baseHost = try parseHost(base)

            var hosts: [DomainName] = []

            if includeApex {
                hosts.append(baseHost)
            }

            for subdomain in subdomains {
                hosts.append(
                    try parseHost(
                        "\(subdomain).\(baseHost.rawValue)"
                    )
                )
            }

            var variants = variantPrefixes

            if includeWWWVariants {
                variants.append("www")
            }

            let normalizedVariants = try unique(
                variants.map {
                    try parseHost($0).rawValue
                }
            )

            let expandedHosts = try expand(
                hosts: hosts,
                variantPrefixes: normalizedVariants,
                includeVariantCombinations: includeVariantCombinations,
                includeVariantPermutations: includeVariantPermutations
            )

            return .init(
                kind: .exactHosts(
                    unique(expandedHosts)
                )
            )
        }

        public static func subdomains(
            of base: String,
            includeApex: Bool = false
        ) throws -> Self {
            .init(
                kind: .subdomains(
                    base: try parseHost(base),
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
            switch kind {
            case .exactHosts(let hosts):
                return hosts.flatMap { host in
                    schemes.map { scheme in
                        Self.originString(
                            scheme: scheme,
                            host: host.rawValue,
                            port: port
                        )
                    }
                }

            case .subdomains:
                return []
            }
        }

        private static func parseHost(
            _ host: String
        ) throws -> DomainName {
            do {
                return try DomainNameParser.parse(host)
            } catch {
                throw CORSOriginPatternError.invalidHost(
                    host,
                    error
                )
            }
        }

        private static func expand(
            hosts: [DomainName],
            variantPrefixes: [String],
            includeVariantCombinations: Bool,
            includeVariantPermutations: Bool
        ) throws -> [DomainName] {
            guard !variantPrefixes.isEmpty else {
                return hosts
            }

            let prefixGroups = variantPrefixGroups(
                variantPrefixes,
                includeCombinations: includeVariantCombinations,
                includePermutations: includeVariantPermutations
            )

            var expanded = hosts

            for host in hosts {
                for group in prefixGroups {
                    expanded.append(
                        try parseHost(
                            "\(group.joined(separator: ".")).\(host.rawValue)"
                        )
                    )
                }
            }

            return expanded
        }

        private static func variantPrefixGroups(
            _ variants: [String],
            includeCombinations: Bool,
            includePermutations: Bool
        ) -> [[String]] {
            guard !variants.isEmpty else {
                return []
            }

            if !includeCombinations {
                return variants.map {
                    [$0]
                }
            }

            if includePermutations {
                var groups: [[String]] = []

                for length in 1...variants.count {
                    groups.append(
                        contentsOf: permutations(
                            variants,
                            length: length
                        )
                    )
                }

                return groups
            }

            return orderedSubsets(
                variants
            )
        }

        private static func orderedSubsets(
            _ values: [String]
        ) -> [[String]] {
            var result: [[String]] = []

            func walk(
                index: Int,
                current: [String]
            ) {
                if index == values.count {
                    if !current.isEmpty {
                        result.append(current)
                    }

                    return
                }

                walk(
                    index: index + 1,
                    current: current
                )

                walk(
                    index: index + 1,
                    current: current + [values[index]]
                )
            }

            walk(
                index: 0,
                current: []
            )

            return result
        }

        private static func permutations(
            _ values: [String],
            length: Int
        ) -> [[String]] {
            if length == 0 {
                return [
                    []
                ]
            }

            var result: [[String]] = []

            for index in values.indices {
                var remaining = values
                let value = remaining.remove(
                    at: index
                )

                for suffix in permutations(
                    remaining,
                    length: length - 1
                ) {
                    result.append(
                        [value] + suffix
                    )
                }
            }

            return result
        }

        private static func unique<T: Hashable>(
            _ values: [T]
        ) -> [T] {
            var seen = Set<T>()
            var result: [T] = []

            for value in values {
                if seen.insert(value).inserted {
                    result.append(value)
                }
            }

            return result
        }

        private static func originString(
            scheme: Origin.Scheme,
            host: String,
            port: Int?
        ) -> String {
            let schemeString: String

            switch scheme {
            case .http:
                schemeString = "http"

            case .https:
                schemeString = "https"
            }

            if let port {
                return "\(schemeString)://\(host):\(port)"
            }

            return "\(schemeString)://\(host)"
        }
    }
}
