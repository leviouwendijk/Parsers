import Foundation
import Parsing

extension Prebuilt.Content {
    public struct KeywordBlockParser<Content: Sendable>: TokenParser {
        public typealias Output = Content

        public let inner: BlockParser<String, Content>

        public init(
            keyword: String,
            delimiter: GrammarNode.Delim = .braces,
            content: AnyTokenParser<Content>,
            skip: AnyTokenParser<Void> = Skip.trivia()
        ) {
            self.inner = .init(
                prefix: AnyTokenParser(
                    PKeyword(keyword).map { Optional.some($0) }
                ),
                delimiter: delimiter,
                content: content,
                skip: skip
            )
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<Content> {
            switch inner.parse(cursor) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)

                case .success(let output, let next):
                    return .success(output.content, next)
            }
        }
    }
}
