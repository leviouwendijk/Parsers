import Foundation
import Parsing
import Primitives

extension Prebuilt.Content {
    public struct DateSpecificationBlockParser: TokenParser {
        public typealias Output = DateSpecification

        public let partial: AnyTokenParser<PartialDate>
        public let timeZone: TimeZone

        public init(
            assignment: AnyTokenParser<Void>,
            skip: AnyTokenParser<Void> = Skip.accountingLike(),
            timeZone: TimeZone
        ) {
            self.partial = AnyTokenParser(
                DateBraceBlockParser(
                    assignment: assignment,
                    skip: skip
                )
            )
            self.timeZone = timeZone
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<DateSpecification> {
            switch partial.parse(cursor) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)

                case .success(let partialDate, let next):
                    do {
                        let date = try partialDate.resolve(in: timeZone)
                        return .success(.absolute(date), next)
                    } catch {
                        return .failure(
                            Diagnostic(error.localizedDescription)
                        )
                    }
            }
        }
    }
}
