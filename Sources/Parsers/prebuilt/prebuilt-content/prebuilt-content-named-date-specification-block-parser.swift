import Foundation
import Parsing
import Primitives

extension Prebuilt.Content {
    public struct NamedDateSpecificationBlockParser: TokenParser {
        public typealias Output = DateSpecification

        public let inner: AnyTokenParser<PartialDate>
        public let timeZone: TimeZone

        public init(
            keyword: String,
            assignment: AnyTokenParser<Void>,
            skip: AnyTokenParser<Void> = Skip.trivia(),
            timeZone: TimeZone
        ) {
            self.inner = AnyTokenParser(
                KeywordBlockParser(
                    keyword: keyword,
                    delimiter: .braces,
                    content: AnyTokenParser(
                        DateBlockParser(
                            assignment: assignment,
                            skip: skip
                        )
                    ),
                    skip: skip
                )
            )
            self.timeZone = timeZone
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<DateSpecification> {
            switch inner.parse(cursor) {
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
