import Foundation
import Parsing
import Primitives

extension Prebuilt.Content {
    public enum DateBlockParserError: Error, LocalizedError, Sendable, Equatable {
        case duplicateField(String)
        case unexpectedField(String)
        case expectedNumericValue(String)

        public var errorDescription: String? {
            switch self {
                case .duplicateField(let name):
                    return "Duplicate field '\(name)'"
                case .unexpectedField(let name):
                    return "Unexpected field '\(name)'"
                case .expectedNumericValue(let name):
                    return "Expected numeric value for field '\(name)'"
            }
        }
    }

    public struct DateBlockParser: TokenParser {
        public typealias Output = PartialDate

        public let assignment: AnyTokenParser<Void>
        public let separator: AnyTokenParser<Void>

        public init(
            assignment: AnyTokenParser<Void>,
            separator: AnyTokenParser<Void> = AnyTokenParser { c in
                .success((), c)
            }
        ) {
            self.assignment = assignment
            self.separator = separator
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<PartialDate> {
            var cur = cursor
            var year: Int?
            var month: Int?
            var day: Int?

            while true {
                switch PIdent().parse(cur) {
                    case .failure:
                        return .success(
                            PartialDate(
                                year: year,
                                month: month,
                                day: day
                            ),
                            cur
                        )

                    case .success(let fieldName, let afterField):
                        cur = afterField

                        switch assignment.parse(cur) {
                            case .failure(let diagnostic):
                                return .failure(diagnostic)
                            case .success(_, let afterAssignment):
                                cur = afterAssignment
                        }

                        switch PNumber().parse(cur) {
                            case .failure:
                                return .failure(
                                    Diagnostic(
                                        DateBlockParserError
                                            .expectedNumericValue(fieldName)
                                            .localizedDescription
                                    )
                                )

                            case .success(let value, let afterValue):
                                cur = afterValue

                                let intValue = NSDecimalNumber(decimal: value).intValue

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
                        }

                        switch separator.parse(cur) {
                            case .success(_, let afterSeparator):
                                cur = afterSeparator
                            case .failure:
                                break
                        }
                }
            }
        }
    }
}
