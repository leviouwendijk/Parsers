import Foundation
import Parsing
import Primitives

extension Prebuilt.Content {
    public struct DateBraceBlockParser: TokenParser {
        public typealias Output = PartialDate

        public let inner: BlockParser<Never, PartialDate>

        public init(
            assignment: AnyTokenParser<Void>,
            skip: AnyTokenParser<Void> = Skip.trivia()
        ) {
            self.inner = .init(
                delimiter: .braces,
                content: AnyTokenParser(
                    DateBlockParser(
                        assignment: assignment,
                        skip: skip
                    )
                ),
                skip: skip
            )
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<PartialDate> {
            switch inner.parse(cursor) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)

                case .success(let output, let next):
                    return .success(output.content, next)
            }
        }
    }
}
