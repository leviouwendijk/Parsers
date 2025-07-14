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
        var prev: NorgToken?


        for token in tokens {
            switch token {
            case .bold(let txt):
                append(" ", if: needsSpace(prev, token), to: result)
                result.append(NSAttributedString(
                    string: txt,
                    attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
                ))
            case .italic(let txt):
                append(" ", if: needsSpace(prev, token), to: result)
                let italicFont = NSFontManager.shared
                    .convert(NSFont.systemFont(ofSize: NSFont.systemFontSize),
                             toHaveTrait: .italicFontMask)
                result.append(NSAttributedString(string: txt,
                                                attributes: [.font: italicFont]))
            case .plain(let txt):
                append(" ", if: needsSpace(prev, token), to: result)
                result.append(NSAttributedString(string: txt))
            case .header(let txt):
                let lvl = txt.prefix { $0 == "*" }.count
                let size = NSFont.systemFontSize + CGFloat(max(6 - lvl, 0))
                result.append(NSAttributedString(
                    string: txt.trimmingCharacters(in: .whitespaces) + "\n",
                    attributes: [.font: NSFont.boldSystemFont(ofSize: size)]
                ))
            case .emptyLine:
                result.append(NSAttributedString(string: "\n\n"))
            case .inlineFootnoteReference(let ref):
                result.append(NSAttributedString(
                    string: "[\(ref)]",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize - 2),
                        .foregroundColor: NSColor.blue
                    ]
                ))
            case .singleFootnote(let title, let content):
                result.append(footnote(title: title, content: content))
            case .multiFootnote(let title, let content):
                result.append(footnote(title: "[\(title)]", content: content))
            }
            prev = token
        }

        return result
    }

    private func append(
        _ s: String,
        if cond: Bool,
        to buf: NSMutableAttributedString,
        conservativeSpace mitigatingDoubleSpaceInjection: Bool = true
    ) {
        guard cond else { return }
        
        if mitigatingDoubleSpaceInjection {
            guard !(s == " " && buf.string.hasSuffix(" ")) else { return } 
        }

        buf.append(NSAttributedString(string: s))
    }

    private func needsSpace(_ a: NorgToken?, _ b: NorgToken) -> Bool {
        guard let a = a else { return false }
        switch (a, b) {

        case (.plain(let p), .plain(let c)):
            if p.last == "”" || p.last == "’" { return ![",",".",";",":"].contains(c.first) }
            if p.hasSuffix("—") || c.hasPrefix("—") { return false }
            return !p.hasSuffix(" ") && !c.hasPrefix(" ")

        case (.italic, .plain(let c)), (.bold, .plain(let c)):
            if c.first == "—" { return false }
            return ![",",".",";",":","!","?"].contains(c.first)

        case (.plain(let p), .italic), (.plain(let p), .bold):
            if p.hasSuffix("—") || p.last == "“" || p.last == "(" { return false }
            return !p.hasSuffix(" ")

        case (.italic, .italic), (.bold, .bold):
            return false

        default:
            return true
        }
    }

    private func footnote(title: String, content: String) -> NSAttributedString {
        let buf = NSMutableAttributedString()
        buf.append(NSAttributedString(string: "Footnote \(title):\n",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize - 2),
                .foregroundColor: NSColor.darkGray
            ]))
        buf.append(NSAttributedString(string: content + "\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize - 2),
                .foregroundColor: NSColor.gray
            ]))
        return buf
    }
}
