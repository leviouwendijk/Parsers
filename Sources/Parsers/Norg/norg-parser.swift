import Foundation
import AppKit

public struct NorgParser {
    public let tokens: [NorgToken]

    public init(
        tokens: [NorgToken]
    ) {
        self.tokens = tokens
    }

    public func parse() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for token in tokens {
            switch token {
            case .whitespace(let ws):
                result.append(
                    NSAttributedString(string: ws)
                )

            case .bold(let txt):
                result.append(
                    NSAttributedString(
                        string: txt,
                        attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
                    )
                )

            case .italic(let txt):
                let it = NSFontManager.shared.convert(
                    NSFont.systemFont(ofSize: NSFont.systemFontSize),
                    toHaveTrait: .italicFontMask
                )
                result.append(
                    NSAttributedString(string: txt, attributes: [.font: it])
                )

            case .plain(let txt):
                result.append(
                    NSAttributedString(string: txt)
                )

            case .header(let txt):
                let lvl = txt.prefix { $0 == "*" }.count
                let size = NSFont.systemFontSize + CGFloat(max(6 - lvl, 0))
                result.append(
                    NSAttributedString(
                        string: txt.trimmingCharacters(in: .whitespaces) + "\n",
                        attributes: [.font: NSFont.boldSystemFont(ofSize: size)]
                    )
                )

            case .emptyLine:
                result.append(
                    NSAttributedString(string: "\n\n")
                )

            case .inlineFootnoteReference(let ref):
                result.append(
                    NSAttributedString(
                        string: "[\(ref)]",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize - 2),
                            .foregroundColor: NSColor.blue
                        ]
                    )
                )

            case .singleFootnote(let title, let content):
                result.append(
                    footnote(title: title, content: content)
                )

            case .multiFootnote(let title, let content):
                result.append(
                    footnote(title: "[\(title)]", content: content)
                )
            }
        }
        return result
    }

    public func footnote(title: String, content: String) -> NSAttributedString {
        let buf = NSMutableAttributedString()
        buf.append(
            NSAttributedString(
                string: "Footnote \(title):\n",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize - 2),
                    .foregroundColor: NSColor.darkGray
                ]
            )
        )
        buf.append(
            NSAttributedString(
                string: content + "\n\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize - 2),
                    .foregroundColor: NSColor.gray
                ]
            )
        )
        return buf
    }
}
