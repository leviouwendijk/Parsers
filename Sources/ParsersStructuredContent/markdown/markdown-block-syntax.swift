import DSL
import Foundation

extension MarkdownBlockParser {
    func startsBlock(
        _ line: String
    ) -> Bool {
        heading(in: line) != nil
            || fence(in: line) != nil
            || isQuote(line)
            || listMarker(in: line) != nil
    }

    func heading(
        in line: String
    ) -> Heading? {
        let content = line.drop {
            $0 == " "
        }

        let markerCount = content.prefix {
            $0 == "#"
        }.count

        guard (1...6).contains(markerCount)
        else {
            return nil
        }

        let markerEnd = content.index(
            content.startIndex,
            offsetBy: markerCount
        )

        guard markerEnd < content.endIndex,
              content[markerEnd].isWhitespace
        else {
            return nil
        }

        let title = String(
            content[markerEnd...]
        )
        .trimmingCharacters(
            in: .whitespaces
        )

        return Heading(
            level: markerCount,
            title: title
        )
    }

    func fence(
        in line: String
    ) -> Fence? {
        let content = line.drop {
            $0 == " "
        }

        guard let marker = content.first,
              marker == "`" || marker == "~"
        else {
            return nil
        }

        let count = content.prefix {
            $0 == marker
        }.count

        guard count >= 3 else {
            return nil
        }

        let infoStart = content.index(
            content.startIndex,
            offsetBy: count
        )

        let info = String(
            content[infoStart...]
        )
        .trimmingCharacters(
            in: .whitespaces
        )

        return Fence(
            marker: marker,
            count: count,
            language: info.isEmpty
                ? nil
                : info
        )
    }

    func closesFence(
        _ line: String,
        fence: Fence
    ) -> Bool {
        let content = line.drop {
            $0 == " "
        }

        let count = content.prefix {
            $0 == fence.marker
        }.count

        guard count >= fence.count else {
            return false
        }

        let markerEnd = content.index(
            content.startIndex,
            offsetBy: count
        )

        return content[markerEnd...]
            .allSatisfy {
                $0.isWhitespace
            }
    }

    func isQuote(
        _ line: String
    ) -> Bool {
        quoteContent(line) != nil
    }

    func quoteContent(
        _ line: String
    ) -> String? {
        let content = line.drop {
            $0 == " "
        }

        guard content.first == ">"
        else {
            return nil
        }

        var remainder = content.dropFirst()

        if remainder.first == " " {
            remainder = remainder.dropFirst()
        }

        return String(
            remainder
        )
    }

    func listMarker(
        in line: String
    ) -> ListMarker? {
        let indent = leadingIndent(
            in: line
        )

        let body = line.drop {
            $0 == " " || $0 == "\t"
        }

        if let first = body.first,
           first == "-" || first == "*" || first == "+"
        {
            let afterMarker = body.dropFirst()

            guard afterMarker.isEmpty
                    || afterMarker.first?.isWhitespace == true
            else {
                return nil
            }

            return ListMarker(
                indent: indent,
                style: .unordered,
                content:
                    String(afterMarker)
                        .trimmingCharacters(
                            in: .whitespaces
                        )
            )
        }

        let digits = body.prefix {
            $0.isNumber
        }

        guard !digits.isEmpty else {
            return nil
        }

        let punctuationIndex = body.index(
            body.startIndex,
            offsetBy: digits.count
        )

        guard punctuationIndex < body.endIndex,
              body[punctuationIndex] == "."
        else {
            return nil
        }

        let afterPunctuation = body.index(
            after: punctuationIndex
        )

        guard afterPunctuation == body.endIndex
                || body[afterPunctuation].isWhitespace
        else {
            return nil
        }

        return ListMarker(
            indent: indent,
            style: .ordered,
            content:
                String(
                    body[afterPunctuation...]
                )
                .trimmingCharacters(
                    in: .whitespaces
                )
        )
    }

    /// A row of cells followed by a delimiter row (`|---|:--:|`) with the
    /// same number of cells.
    func startsTable(
        at index: Int
    ) -> Bool {
        guard index + 1 < lines.count,
              let header = tableCells(in: lines[index]),
              let delimiter = tableCells(in: lines[index + 1]),
              header.count == delimiter.count
        else {
            return false
        }

        return delimiter.allSatisfy { cell in
            var body = Substring(cell)

            if body.first == ":" {
                body = body.dropFirst()
            }

            if body.last == ":" {
                body = body.dropLast()
            }

            return !body.isEmpty
                && body.allSatisfy { $0 == "-" }
        }
    }

    /// Cells of a table row, split on `|` outside code spans; `\|` is a
    /// literal pipe. Nil when the line has no pipe.
    func tableCells(
        in line: String
    ) -> [String]? {
        var content = Substring(
            line.trimmingCharacters(
                in: .whitespaces
            )
        )

        guard content.contains("|") else {
            return nil
        }

        if content.first == "|" {
            content = content.dropFirst()
        }

        if content.last == "|",
           !content.hasSuffix("\\|")
        {
            content = content.dropLast()
        }

        var cells: [String] = []
        var current = ""
        var inCode = false
        var escaped = false

        for character in content {
            if escaped {
                if character != "|" {
                    current.append("\\")
                }

                current.append(character)
                escaped = false
                continue
            }

            switch character {
            case "\\":
                escaped = true

            case "`":
                inCode.toggle()
                current.append(character)

            case "|" where !inCode:
                cells.append(
                    current.trimmingCharacters(
                        in: .whitespaces
                    )
                )
                current = ""

            default:
                current.append(character)
            }
        }

        if escaped {
            current.append("\\")
        }

        cells.append(
            current.trimmingCharacters(
                in: .whitespaces
            )
        )

        return cells
    }

    func leadingIndent(
        in line: String
    ) -> Int {
        var width = 0

        for character in line {
            switch character {
            case " ":
                width += 1

            case "\t":
                width += 4

            default:
                return width
            }
        }

        return width
    }

    func isBlank(
        _ line: String
    ) -> Bool {
        line.allSatisfy {
            $0.isWhitespace
        }
    }

    func collapse(
        _ blocks: [StructuredContent]
    ) -> StructuredContent {
        if blocks.count == 1,
           let only = blocks.first
        {
            return only
        }

        return .collection(
            blocks
        )
    }
}
