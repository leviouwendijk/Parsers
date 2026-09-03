import DSL
import Foundation

struct MarkdownBlockParser {
    struct Heading {
        let level: Int
        let title: String
    }

    struct Fence {
        let marker: Character
        let count: Int
        let language: String?
    }

    struct ListMarker {
        let indent: Int
        let style: StructuredContent.ListStyle
        let content: String
    }

    let lines: [String]
    var index = 0

    init(
        source: String
    ) {
        self.lines = source.components(
            separatedBy: .newlines
        )
    }

    mutating func parse() -> StructuredContent {
        .collection(
            parseBlocks(
                stoppingBeforeHeadingAtOrAbove: nil
            )
        )
    }

    private mutating func parseBlocks(
        stoppingBeforeHeadingAtOrAbove level: Int?
    ) -> [StructuredContent] {
        var blocks: [StructuredContent] = []

        while index < lines.count {
            if isBlank(lines[index]) {
                index += 1
                continue
            }

            if let heading = heading(in: lines[index]) {
                if let level,
                   heading.level <= level
                {
                    break
                }

                blocks.append(
                    parseSection(
                        heading
                    )
                )
                continue
            }

            blocks.append(
                parseBlock()
            )
        }

        return blocks
    }

    private mutating func parseSection(
        _ heading: Heading
    ) -> StructuredContent {
        index += 1

        let content = parseBlocks(
            stoppingBeforeHeadingAtOrAbove:
                heading.level
        )

        return .group(
            role: .init(
                rawValue:
                    "markdown.heading.\(heading.level)"
            ),
            title: MarkdownInlineParser.parse(
                heading.title
            ),
            content: .collection(
                content
            )
        )
    }

    private mutating func parseBlock() -> StructuredContent {
        if let fence = fence(in: lines[index]) {
            return parseFence(
                fence
            )
        }

        if isQuote(lines[index]) {
            return parseQuote()
        }

        if let marker = listMarker(in: lines[index]) {
            return parseList(
                startingWith: marker
            )
        }

        return parseParagraph()
    }

    private mutating func parseFence(
        _ fence: Fence
    ) -> StructuredContent {
        index += 1

        var sourceLines: [String] = []

        while index < lines.count {
            if closesFence(
                lines[index],
                fence: fence
            ) {
                index += 1
                break
            }

            sourceLines.append(
                lines[index]
            )
            index += 1
        }

        return .code(
            language: fence.language,
            source: sourceLines.joined(
                separator: "\n"
            )
        )
    }

    private mutating func parseQuote() -> StructuredContent {
        var quoteLines: [String] = []

        while index < lines.count {
            guard let content = quoteContent(
                lines[index]
            ) else {
                break
            }

            quoteLines.append(
                content
            )
            index += 1
        }

        var nested = MarkdownBlockParser(
            source: quoteLines.joined(
                separator: "\n"
            )
        )

        return .quote(
            nested.parse()
        )
    }

    private mutating func parseList(
        startingWith first: ListMarker
    ) -> StructuredContent {
        let baseIndent = first.indent
        let style = first.style

        var items: [StructuredContent] = []

        while index < lines.count {
            guard let marker = listMarker(
                in: lines[index]
            ),
            marker.indent == baseIndent,
            marker.style == style
            else {
                break
            }

            index += 1

            var itemBlocks: [StructuredContent] = []

            if !marker.content.isEmpty {
                itemBlocks.append(
                    .paragraph(
                        MarkdownInlineParser.parse(
                            marker.content
                        )
                    )
                )
            }

            while index < lines.count {
                if isBlank(lines[index]) {
                    break
                }

                if let nestedMarker = listMarker(
                    in: lines[index]
                ) {
                    if nestedMarker.indent > baseIndent {
                        itemBlocks.append(
                            parseList(
                                startingWith: nestedMarker
                            )
                        )
                        continue
                    }

                    break
                }

                let continuationIndent =
                    leadingIndent(
                        in: lines[index]
                    )

                guard continuationIndent > baseIndent else {
                    break
                }

                let continuation = lines[index]
                    .trimmingCharacters(
                        in: .whitespaces
                    )

                index += 1

                if !continuation.isEmpty {
                    itemBlocks.append(
                        .paragraph(
                            MarkdownInlineParser.parse(
                                continuation
                            )
                        )
                    )
                }
            }

            items.append(
                collapse(
                    itemBlocks
                )
            )
        }

        return .list(
            style: style,
            items: items
        )
    }

    private mutating func parseParagraph() -> StructuredContent {
        var paragraphLines: [String] = []

        while index < lines.count {
            let line = lines[index]

            if isBlank(line) {
                break
            }

            if !paragraphLines.isEmpty,
               startsBlock(line)
            {
                break
            }

            paragraphLines.append(
                line.trimmingCharacters(
                    in: .whitespaces
                )
            )
            index += 1
        }

        return .paragraph(
            MarkdownInlineParser.parse(
                paragraphLines.joined(
                    separator: " "
                )
            )
        )
    }
}
