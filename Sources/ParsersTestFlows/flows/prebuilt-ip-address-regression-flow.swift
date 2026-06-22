import Foundation
import Parsers
import TestFlows

extension ParserFlowSuite {
    static let prebuiltIPAddressRegressionFlow = TestFlow(
        "prebuilt.ip-address.regression",
        title: "Prebuilt IP address parsers preserve expected behavior",
        tags: [
            "parsers",
            "prebuilt",
            "ip",
            "forwarded-client-ip",
            "bounded-integer",
            "regression"
        ]
    ) {
        Step("bounded integer parses values inside range") {
            let zero = try Prebuilt.BoundedIntegerParser.parse(
                "0",
                range: 0...255
            )

            try Expect.equal(
                zero.rawValue,
                0,
                "bounded-integer.zero"
            )

            let max = try Prebuilt.BoundedIntegerParser.parse(
                "255",
                range: 0...255
            )

            try Expect.equal(
                max.rawValue,
                255,
                "bounded-integer.max"
            )

            let padded = try Prebuilt.BoundedIntegerParser.parse(
                "001",
                range: 0...255
            )

            try Expect.equal(
                padded.rawValue,
                1,
                "bounded-integer.padded"
            )
        }

        Step("bounded integer rejects empty, non-digits, and out-of-range values") {
            try Expect.throwsError(
                "bounded-integer.empty"
            ) {
                _ = try Prebuilt.BoundedIntegerParser.parse(
                    "",
                    range: 0...255
                )
            }

            try Expect.throwsError(
                "bounded-integer.alpha"
            ) {
                _ = try Prebuilt.BoundedIntegerParser.parse(
                    "12x",
                    range: 0...255
                )
            }

            try Expect.throwsError(
                "bounded-integer.out-of-range"
            ) {
                _ = try Prebuilt.BoundedIntegerParser.parse(
                    "256",
                    range: 0...255
                )
            }
        }

        Step("IPv4 parser accepts and normalizes ordinary IPv4 addresses") {
            let ip = try Prebuilt.IPAddressParser.parse(
                "203.0.113.10"
            )

            try Expect.equal(
                ip.rawValue,
                "203.0.113.10",
                "ip-address.ipv4.raw"
            )

            try Expect.equal(
                ip.kind,
                .ipv4,
                "ip-address.ipv4.kind"
            )

            let normalized = try Prebuilt.IPAddressParser.parse(
                " 010.000.000.001 "
            )

            try Expect.equal(
                normalized.rawValue,
                "10.0.0.1",
                "ip-address.ipv4.normalized"
            )
        }

        Step("IPv4 parser rejects malformed or unspecified IPv4 addresses") {
            try Expect.throwsError(
                "ip-address.ipv4.empty"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("")
            }

            try Expect.throwsError(
                "ip-address.ipv4.too-few-octets"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("203.0.113")
            }

            try Expect.throwsError(
                "ip-address.ipv4.too-large-octet"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("203.0.113.256")
            }

            try Expect.throwsError(
                "ip-address.ipv4.non-digit-octet"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("203.0.x.10")
            }

            try Expect.throwsError(
                "ip-address.ipv4.unspecified-default"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("0.0.0.0")
            }
        }

        Step("IPv4 parser can allow unspecified address explicitly") {
            let ip = try Prebuilt.IPAddressParser.parse(
                "0.0.0.0",
                config: .init(
                    allowUnspecified: true
                )
            )

            try Expect.equal(
                ip.rawValue,
                "0.0.0.0",
                "ip-address.ipv4.unspecified.allowed.raw"
            )

            try Expect.equal(
                ip.kind,
                .ipv4,
                "ip-address.ipv4.unspecified.allowed.kind"
            )
        }

        Step("IPv6 parser accepts simple IPv6 literals and lowercases them") {
            let ip = try Prebuilt.IPAddressParser.parse(
                "2001:DB8::17"
            )

            try Expect.equal(
                ip.rawValue,
                "2001:db8::17",
                "ip-address.ipv6.lowercased"
            )

            try Expect.equal(
                ip.kind,
                .ipv6,
                "ip-address.ipv6.kind"
            )
        }

        Step("IPv6 parser rejects invalid characters and unspecified default") {
            try Expect.throwsError(
                "ip-address.ipv6.invalid-character"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("2001:db8::zz")
            }

            try Expect.throwsError(
                "ip-address.ipv6.unspecified-default"
            ) {
                _ = try Prebuilt.IPAddressParser.parse("::")
            }
        }

        Step("IPv6 parser can allow unspecified address explicitly") {
            let ip = try Prebuilt.IPAddressParser.parse(
                "::",
                config: .init(
                    allowUnspecified: true
                )
            )

            try Expect.equal(
                ip.rawValue,
                "::",
                "ip-address.ipv6.unspecified.allowed.raw"
            )

            try Expect.equal(
                ip.kind,
                .ipv6,
                "ip-address.ipv6.unspecified.allowed.kind"
            )
        }

        Step("forwarded client IP parser accepts first address from forwarded chain") {
            let ip = try Prebuilt.ForwardedClientIPParser.parse(
                "203.0.113.10, 10.100.0.1, 10.90.20.15"
            )

            try Expect.equal(
                ip.rawValue,
                "203.0.113.10",
                "forwarded-client-ip.first.raw"
            )

            try Expect.equal(
                ip.ip.kind,
                .ipv4,
                "forwarded-client-ip.first.kind"
            )
        }

        Step("forwarded client IP parser accepts IPv6 first address") {
            let ip = try Prebuilt.ForwardedClientIPParser.parse(
                "2001:db8::17, 10.100.0.1"
            )

            try Expect.equal(
                ip.rawValue,
                "2001:db8::17",
                "forwarded-client-ip.ipv6.raw"
            )

            try Expect.equal(
                ip.ip.kind,
                .ipv6,
                "forwarded-client-ip.ipv6.kind"
            )
        }

        Step("forwarded client IP parser rejects missing, empty, invalid, and unspecified chains") {
            try Expect.throwsError(
                "forwarded-client-ip.missing"
            ) {
                _ = try Prebuilt.ForwardedClientIPParser.parse(nil)
            }

            try Expect.throwsError(
                "forwarded-client-ip.empty"
            ) {
                _ = try Prebuilt.ForwardedClientIPParser.parse("")
            }

            try Expect.throwsError(
                "forwarded-client-ip.invalid"
            ) {
                _ = try Prebuilt.ForwardedClientIPParser.parse("not-an-ip")
            }

            try Expect.throwsError(
                "forwarded-client-ip.unspecified"
            ) {
                _ = try Prebuilt.ForwardedClientIPParser.parse("0.0.0.0")
            }
        }
    }
}
