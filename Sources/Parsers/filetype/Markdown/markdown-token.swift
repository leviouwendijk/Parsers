import Foundation

public enum MarkdownToken: CustomStringConvertible {
    case heading(level: Int, text: String)
    case blockquoteLine(String)
    case unorderedListItemStart
    case orderedListItemStart(Int)
    case codeBlock(language: String?, content: String)
    case horizontalRule
    case emptyLine
    case lineBreak

    case plain(String)
    case whitespace(String)
    case bold(String)
    case italic(String)
    case strikethrough(String)
    case codeSpan(String)
    case link(text: String, url: String)
    case image(alt: String, url: String)

    public var description: String {
        switch self {
        case .heading(let l, let t): return "Heading(\(l), \"\(t)\")"
        case .blockquoteLine(let t): return "Blockquote(\"\(t)\")"
        case .unorderedListItemStart: return "ULItemStart"
        case .orderedListItemStart(let n): return "OLItemStart(\(n))"
        case .codeBlock(let lang, let c): return "CodeBlock(\(lang ?? "nil"), \(c.count) chars)"
        case .horizontalRule: return "HR"
        case .emptyLine: return "EmptyLine"
        case .lineBreak: return "LineBreak"
        case .plain(let s): return "Plain(\"\(s)\")"
        case .whitespace(let s): return "WS(\"\(s)\")"
        case .bold(let s): return "Bold(\"\(s)\")"
        case .italic(let s): return "Italic(\"\(s)\")"
        case .strikethrough(let s): return "Strike(\"\(s)\")"
        case .codeSpan(let s): return "CodeSpan(\"\(s)\")"
        case .link(let t, let u): return "Link(\"\(t)\", \"\(u)\")"
        case .image(let a, let u): return "Image(\"\(a)\", \"\(u)\")"
        }
    }
}
