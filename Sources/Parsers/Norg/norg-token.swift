import Foundation

public enum NorgToken: CustomStringConvertible {
    case bold(String)
    case italic(String)
    case plain(String)
    case whitespace(String)
    case header(String)
    case emptyLine
    case inlineFootnoteReference(String)
    case singleFootnote(String, String)
    case multiFootnote(String, String)

    public var description: String {
        switch self {
        case .bold(let text): return "Bold(\"\(text)\")"
        case .italic(let text): return "Italic(\"\(text)\")"
        case .plain(let text): return "Plain(\"\(text)\")"
        case .whitespace(let s): return "Whitespace(\"\(s)\")"
        case .header(let text): return "Header(\"\(text)\")"
        case .emptyLine: return "EmptyLine"
        case .inlineFootnoteReference(let ref): return "InlineFoot(\"\(ref)\")"
        case .singleFootnote(let title, let content): return "SingleFoot(\"\(title)\", \"\(content)\")"
        case .multiFootnote(let title, let content): return "MultiFoot(\"\(title)\", \"\(content)\")"
        }
    }
}
