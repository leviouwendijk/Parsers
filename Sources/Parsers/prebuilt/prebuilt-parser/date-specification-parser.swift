import Foundation
import Parsing
import Primitives

extension Prebuilt {
    public enum DateSpecificationParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case inferDisallowed
        case invalidInferSyntax
        case invalidLiteral(String)
        case invalidUnixEpoch(String)

        public var errorDescription: String? {
            switch self {
                case .empty:
                    return "Date specification cannot be empty"
                case .inferDisallowed:
                    return "Infer date specification is not allowed here"
                case .invalidInferSyntax:
                    return "Invalid infer syntax, expected 'infer <day>'"
                case .invalidLiteral(let value):
                    return "Invalid date literal '\(value)'"
                case .invalidUnixEpoch(let value):
                    return "Invalid unix epoch '\(value)'"
            }
        }
    }

    public struct DateSpecificationParser: Parser, Sendable {
        public struct Configuration: Sendable, Hashable {
            public var allowInfer: Bool
            public var allowUnixEpoch: Bool
            public var timeZone: TimeZone

            public init(
                allowInfer: Bool = true,
                allowUnixEpoch: Bool = false,
                timeZone: TimeZone = .current
            ) {
                self.allowInfer = allowInfer
                self.allowUnixEpoch = allowUnixEpoch
                self.timeZone = timeZone
            }
        }

        public typealias Output = DateSpecification

        public let config: Configuration

        public init(config: Configuration = .init()) {
            self.config = config
        }

        public func parse(_ cursor: Cursor) -> ParseResult<DateSpecification> {
            var cur = cursor
            let start = cur.mark()

            do {
                let output = try Self.parseDateSpecification(&cur, config: config)
                return .success(output, cur)
            } catch let error as DateSpecificationParserError {
                let diagnostic = Diagnostic(
                    error.localizedDescription,
                    range: cur.range(from: start)
                )
                return .failure(diagnostic)
            } catch let error as DateSpecificationError {
                let diagnostic = Diagnostic(
                    error.localizedDescription,
                    range: cur.range(from: start)
                )
                return .failure(diagnostic)
            } catch {
                let diagnostic = Diagnostic(
                    "Date specification parse failed: \(error.localizedDescription)",
                    range: cur.range(from: start)
                )
                return .failure(diagnostic)
            }
        }

        public static func parse(
            _ input: String,
            config: Configuration = .init()
        ) throws -> DateSpecification {
            var cur = Cursor(input)
            let output = try parseDateSpecification(&cur, config: config)

            if cur.peek() != nil {
                throw DateSpecificationParserError.invalidLiteral(String(cur.slice(from: cur.mark())))
            }

            return output
        }

        private static func parseDateSpecification(
            _ cursor: inout Cursor,
            config: Configuration
        ) throws -> DateSpecification {
            let raw = cursor.input
                .trimmingCharacters(in: .whitespacesAndNewlines)

            while cursor.peek() != nil {
                cursor.advance()
            }

            guard !raw.isEmpty else {
                throw DateSpecificationParserError.empty
            }

            if raw.hasPrefix("infer") {
                return try parseInfer(raw, config: config)
            }

            if config.allowUnixEpoch, isLikelyUnixEpoch(raw) {
                return try parseUnixEpoch(raw)
            }

            return try parseISODate(raw, timeZone: config.timeZone)
        }

        private static func parseInfer(
            _ raw: String,
            config: Configuration
        ) throws -> DateSpecification {
            guard config.allowInfer else {
                throw DateSpecificationParserError.inferDisallowed
            }

            let parts = raw
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)

            guard parts.count == 2, parts[0] == "infer", let day = Int(parts[1]) else {
                throw DateSpecificationParserError.invalidInferSyntax
            }

            return try DateSpecification(inferDay: day)
        }

        private static func parseUnixEpoch(
            _ raw: String
        ) throws -> DateSpecification {
            guard let seconds = Double(raw) else {
                throw DateSpecificationParserError.invalidUnixEpoch(raw)
            }

            return .absolute(Date(timeIntervalSince1970: seconds))
        }

        private static func parseISODate(
            _ raw: String,
            timeZone: TimeZone
        ) throws -> DateSpecification {
            let parts = raw
                .split(separator: "-", omittingEmptySubsequences: false)
                .map(String.init)

            guard
                parts.count == 3,
                let year = Int(parts[0]),
                let month = Int(parts[1]),
                let day = Int(parts[2])
            else {
                throw DateSpecificationParserError.invalidLiteral(raw)
            }

            let partial = PartialDate(
                year: year,
                month: month,
                day: day
            )

            return .absolute(try partial.resolve(in: timeZone))
        }

        private static func isLikelyUnixEpoch(_ raw: String) -> Bool {
            raw.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
        }
    }
}
