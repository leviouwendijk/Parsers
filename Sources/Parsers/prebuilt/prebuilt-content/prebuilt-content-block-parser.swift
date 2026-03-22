import Foundation
import Parsing

extension Prebuilt.Content {
    public enum Delimiter: Sendable, Hashable {
        case parens
        case brackets
        case braces
    }

    public struct BlockParser<Prefix: Sendable, Content: Sendable>: TokenParser {
        public typealias Output = BlockParseOutput<Prefix, Content>

        public let prefix: AnyTokenParser<Prefix?>
        public let delimiter: Delimiter
        public let content: AnyTokenParser<Content>

        public init(
            prefix: AnyTokenParser<Prefix?>,
            delimiter: Delimiter = .braces,
            content: AnyTokenParser<Content>
        ) {
            self.prefix = prefix
            self.delimiter = delimiter
            self.content = content
        }

        public func parse(
            _ cursor: TokenCursor
        ) -> TokenParseResult<BlockParseOutput<Prefix, Content>> {
            switch prefix.parse(cursor) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)

                case .success(let parsedPrefix, let afterPrefix):
                    let wrapped: AnyTokenParser<Content>

                    switch delimiter {
                        case .parens:
                            wrapped = TokenParsers.parens(content)
                        case .brackets:
                            wrapped = TokenParsers.brackets(content)
                        case .braces:
                            wrapped = TokenParsers.braces(content)
                    }

                    switch wrapped.parse(afterPrefix) {
                        case .failure(let diagnostic):
                            return .failure(diagnostic)

                        case .success(let parsedContent, let next):
                            return .success(
                                .init(
                                    prefix: parsedPrefix,
                                    content: parsedContent
                                ),
                                next
                            )
                    }
            }
        }
    }
}

public extension Prebuilt.Content.BlockParser where Prefix == Never {
    init(
        delimiter: Prebuilt.Content.Delimiter = .braces,
        content: AnyTokenParser<Content>
    ) {
        self.init(
            prefix: AnyTokenParser<Never?> { c in
                .success(nil, c)
            },
            delimiter: delimiter,
            content: content
        )
    }
}
