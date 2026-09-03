import DSL

enum MarkdownInlineParser {
    static func parse(
        _ source: String
    ) -> [StructuredContent.Inline] {
        let characters = Array(
            source
        )

        var result: [StructuredContent.Inline] = []
        var index = 0

        while index < characters.count {
            if characters[index] == "\\",
               index + 1 < characters.count
            {
                appendText(
                    String(
                        characters[index + 1]
                    ),
                    to: &result
                )
                index += 2
                continue
            }

            if characters[index] == "`",
               let closing = closingIndex(
                    for: ["`"],
                    in: characters,
                    from: index + 1
               )
            {
                result.append(
                    .code(
                        String(
                            characters[
                                (index + 1)..<closing
                            ]
                        )
                    )
                )
                index = closing + 1
                continue
            }

            if index + 1 < characters.count,
               characters[index] == characters[index + 1],
               characters[index] == "*"
                    || characters[index] == "_"
            {
                let marker = [
                    characters[index],
                    characters[index + 1],
                ]

                if let closing = closingIndex(
                    for: marker,
                    in: characters,
                    from: index + 2
                ) {
                    let content = String(
                        characters[
                            (index + 2)..<closing
                        ]
                    )

                    result.append(
                        .strong(
                            parse(
                                content
                            )
                        )
                    )

                    index = closing + 2
                    continue
                }
            }

            if characters[index] == "*"
                || characters[index] == "_"
            {
                let marker = [
                    characters[index],
                ]

                if let closing = closingIndex(
                    for: marker,
                    in: characters,
                    from: index + 1
                ) {
                    let content = String(
                        characters[
                            (index + 1)..<closing
                        ]
                    )

                    result.append(
                        .emphasis(
                            parse(
                                content
                            )
                        )
                    )

                    index = closing + 1
                    continue
                }
            }

            appendText(
                String(
                    characters[index]
                ),
                to: &result
            )
            index += 1
        }

        return result
    }

    private static func closingIndex(
        for marker: [Character],
        in characters: [Character],
        from start: Int
    ) -> Int? {
        guard !marker.isEmpty,
              start < characters.count
        else {
            return nil
        }

        var index = start

        while index + marker.count <= characters.count {
            var matches = true

            for offset in marker.indices
            where characters[index + offset] != marker[offset]
            {
                matches = false
                break
            }

            if matches {
                return index
            }

            index += 1
        }

        return nil
    }

    private static func appendText(
        _ text: String,
        to result: inout [StructuredContent.Inline]
    ) {
        guard !text.isEmpty else {
            return
        }

        if let last = result.last,
           case .text(let existing) = last
        {
            result[result.count - 1] =
                .text(
                    existing + text
                )
        } else {
            result.append(
                .text(
                    text
                )
            )
        }
    }
}
