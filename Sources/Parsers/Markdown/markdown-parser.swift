import Foundation
import AppKit

public struct MarkdownParser {
    public let tokens: [MarkdownToken]
    public init(tokens: [MarkdownToken]) { self.tokens = tokens }

    public func parse() -> NSAttributedString {
        let out = NSMutableAttributedString()
        let base = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let bold = NSFont.boldSystemFont(ofSize: base.pointSize)
        let mono = NSFont.monospacedSystemFont(ofSize: base.pointSize, weight: .regular)

        func append(_ s: String, _ attrs: [NSAttributedString.Key: Any] = [:]) {
            out.append(NSAttributedString(string: s, attributes: attrs))
        }

        for t in tokens {
            switch t {
            case .lineBreak, .emptyLine:
                append("\n")
            case .horizontalRule:
                append("————————————\n")

            case .heading(let lvl, let text):
                let size = base.pointSize + CGFloat(8 - min(lvl, 6))
                append(normalizeInline(text).trimmingCharacters(in: .whitespaces),
                       [.font: NSFont.boldSystemFont(ofSize: size)])

            case .blockquoteLine:
                append("› ", [.foregroundColor: NSColor.systemGray])

            case .unorderedListItemStart:
                append("• ")
            case .orderedListItemStart(let n):
                append("\(n). ")

            case .codeBlock(_, let content):
                // do NOT normalize code
                append(content + "\n", [.font: mono])

            case .plain(let s):
                append(normalizeInline(s))
            case .whitespace(let s):
                append(s)
            case .bold(let s):
                append(normalizeInline(s), [.font: bold])
            case .italic(let s):
                let it = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
                append(normalizeInline(s), [.font: it])
            case .strikethrough(let s):
                append(normalizeInline(s), [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
            case .codeSpan(let s):
                append(s, [.font: mono, .backgroundColor: NSColor.textBackgroundColor])
            case .link(let text, let url):
                append(normalizeInline(text), [
                    .link: decodeHTMLEntities(unescapeMarkdownPunctuation(url)),
                    .foregroundColor: NSColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ])
            case .image(let alt, let url):
                append("[image: \(normalizeInline(alt))] ", [
                    .link: decodeHTMLEntities(unescapeMarkdownPunctuation(url)),
                    .foregroundColor: NSColor.systemBlue
                ])
            }
        }
        return out
    }
}
