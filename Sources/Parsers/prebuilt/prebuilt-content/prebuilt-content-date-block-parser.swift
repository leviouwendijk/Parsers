import Foundation
import Parsing
import Primitives

extension Prebuilt.Content {
    public enum DateBlockParserError: Error, LocalizedError, Sendable, Equatable {
        case duplicateField(String)
        case unexpectedField(String)
        case expectedNumericValue(String)
        case expectedIntegerValue(String)

        public var errorDescription: String? {
            switch self {
                case .duplicateField(let name):
                    return "Duplicate field '\(name)'"
                case .unexpectedField(let name):
                    return "Unexpected field '\(name)'"
                case .expectedNumericValue(let name):
                    return "Expected numeric value for field '\(name)'"
                case .expectedIntegerValue(let name):
                    return "Expected integer value for field '\(name)'"
            }
        }
    }

    public struct DateBlockParser: TokenParser {
        public typealias Output = PartialDate

        public let assignment: AnyTokenParser<Void>
        public let skip: AnyTokenParser<Void>

        public init(
            assignment: AnyTokenParser<Void>,
            skip: AnyTokenParser<Void> = Skip.accountingLike()
        ) {
            self.assignment = assignment
            self.skip = skip
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<PartialDate> {
            var cur = cursor
            var year: Int?
            var month: Int?
            var day: Int?

            while true {
                cur = consumeSkip(from: cur)

                if cur.isEOF {
                    cur = consumeSkip(from: cur)
                    return .success(
                        PartialDate(
                            year: year,
                            month: month,
                            day: day
                        ),
                        cur
                    )
                }

                let fieldName: String
                switch PIdent().parse(cur) {
                    case .failure:
                        return .failure(
                            Diagnostic("Expected date field identifier")
                        )

                    case .success(let name, let next):
                        fieldName = name
                        cur = next
                }

                cur = consumeSkip(from: cur)

                switch assignment.parse(cur) {
                    case .failure(let diagnostic):
                        return .failure(diagnostic)

                    case .success(_, let next):
                        cur = next
                }

                cur = consumeSkip(from: cur)

                let decimalValue: Decimal
                switch PNumber().parse(cur) {
                    case .failure:
                        return .failure(
                            Diagnostic(
                                DateBlockParserError
                                    .expectedNumericValue(fieldName)
                                    .localizedDescription
                            )
                        )

                    case .success(let value, let next):
                        decimalValue = value
                        cur = next
                }

                cur = consumeSkip(from: cur)

                guard decimalValue.isWholeNumber else {
                    return .failure(
                        Diagnostic(
                            DateBlockParserError
                                .expectedIntegerValue(fieldName)
                                .localizedDescription
                        )
                    )
                }

                let intValue = NSDecimalNumber(decimal: decimalValue).intValue

                switch fieldName {
                    case "year":
                        guard year == nil else {
                            return .failure(
                                Diagnostic(
                                    DateBlockParserError
                                        .duplicateField(fieldName)
                                        .localizedDescription
                                )
                            )
                        }
                        year = intValue

                    case "month":
                        guard month == nil else {
                            return .failure(
                                Diagnostic(
                                    DateBlockParserError
                                        .duplicateField(fieldName)
                                        .localizedDescription
                                )
                            )
                        }
                        month = intValue

                    case "day":
                        guard day == nil else {
                            return .failure(
                                Diagnostic(
                                    DateBlockParserError
                                        .duplicateField(fieldName)
                                        .localizedDescription
                                )
                            )
                        }
                        day = intValue

                    default:
                        return .failure(
                            Diagnostic(
                                DateBlockParserError
                                    .unexpectedField(fieldName)
                                    .localizedDescription
                            )
                        )
                }

                cur = consumeSkip(from: cur)
            }
        }

        private func consumeSkip(
            from cursor: TokenCursor
        ) -> TokenCursor {
            var cur = cursor

            while true {
                switch skip.parse(cur) {
                    case .success(_, let next):
                        if next.index == cur.index {
                            return cur
                        }
                        cur = next

                    case .failure:
                        return cur
                }
            }
        }
    }
}

private extension Decimal {
    var isWholeNumber: Bool {
        self == rounded(0)
    }

    func rounded(_ scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
