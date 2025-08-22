import Foundation
import plate
import Extensions

public struct MarkdownLexerOptions {
    public let trimLeadingNewlines: Bool
    public let trimTrailingNewlines: Bool
    public init(trimLeadingNewlines: Bool = false, trimTrailingNewlines: Bool = false) {
        self.trimLeadingNewlines = trimLeadingNewlines
        self.trimTrailingNewlines = trimTrailingNewlines
    }
}

public struct MarkdownLexer {
    public let text: String
    public let options: MarkdownLexerOptions
    public let verbose: Bool

    public init(text: String, options: MarkdownLexerOptions = .init(), verbose: Bool = false) {
        self.text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        self.options = options
        self.verbose = verbose
    }

    public init(file: String, options: MarkdownLexerOptions = .init(), verbose: Bool = false) throws {
        self.init(text: try readFile(at: file), options: options, verbose: verbose)
    }

    public func tokenize() -> [MarkdownToken] {
        var tokens: [MarkdownToken] = []
        var lines = text.components(separatedBy: "\n")

        if options.trimLeadingNewlines {
            while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        }
        if options.trimTrailingNewlines {
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
        }

        var inCodeBlock = false
        var codeLang: String? = nil
        var codeBuffer: [String] = []

        let hrRE = try! NSRegularExpression(pattern: #"^\s{0,3}((\-{3,})|(\*{3,})|(_{3,}))\s*$"#)
        let hRE  = try! NSRegularExpression(pattern: #"^\s{0,3}(#{1,6})\s+(.+?)\s*$"#)
        let olRE = try! NSRegularExpression(pattern: #"^\s{0,3}(\d+)[\.\)]\s+(.+)$"#)
        let ulRE = try! NSRegularExpression(pattern: #"^\s{0,3}[\-\+\*]\s+(.+)$"#)
        let bqRE = try! NSRegularExpression(pattern: #"^\s{0,3}>\s?(.*)$"#)
        let fenceStartRE = try! NSRegularExpression(pattern: #"^\s{0,3}```\s*([A-Za-z0-9_\-\+\.]+)?\s*$"#)
        let fenceEndRE   = try! NSRegularExpression(pattern: #"^\s{0,3}```\s*$"#)

        for rawLine in lines {
            let line = rawLine // keep spaces for inline parsing

            if inCodeBlock {
                if fenceEndRE.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil {
                    tokens.append(.codeBlock(language: codeLang, content: codeBuffer.joined(separator: "\n")))
                    tokens.append(.lineBreak)
                    inCodeBlock = false
                    codeLang = nil
                    codeBuffer.removeAll()
                    continue
                } else {
                    codeBuffer.append(rawLine)
                    continue
                }
            }

            if (line as NSString).trimmingCharacters(in: .whitespaces).isEmpty {
                tokens.append(.emptyLine)
                continue
            }

            if let m = fenceStartRE.firstMatch(in: line, range: NSRange(0..<(line as NSString).length)) {
                codeLang = capture(line, m, 1)
                inCodeBlock = true
                codeBuffer.removeAll()
                continue
            }

            if hrRE.firstMatch(in: line, range: NSRange(0..<(line as NSString).length)) != nil {
                tokens.append(.horizontalRule)
                tokens.append(.lineBreak)
                continue
            }

            if let m = hRE.firstMatch(in: line, range: NSRange(0..<(line as NSString).length)) {
                let hashes = capture(line, m, 1)
                let txt = capture(line, m, 2)
                tokens.append(.heading(level: hashes.count, text: txt))
                tokens.append(.lineBreak)
                continue
            }

            if let m = bqRE.firstMatch(in: line, range: NSRange(0..<(line as NSString).length)) {
                let content = capture(line, m, 1)
                if content.isEmpty {
                    tokens.append(.blockquoteLine(""))
                } else {
                    tokens.append(.blockquoteLine(""))
                    tokens.append(contentsOf: parseInline(content))
                }
                tokens.append(.lineBreak)
                continue
            }

            if let m = olRE.firstMatch(in: line, range: NSRange(0..<(line as NSString).length)) {
                let nStr = capture(line, m, 1)
                let body = capture(line, m, 2)
                tokens.append(.orderedListItemStart(Int(nStr) ?? 1))
                tokens.append(contentsOf: parseInline(body))
                tokens.append(.lineBreak)
                continue
            }

            if let m = ulRE.firstMatch(in: line, range: NSRange(0..<(line as NSString).length)) {
                let body = capture(line, m, 1)
                tokens.append(.unorderedListItemStart)
                tokens.append(contentsOf: parseInline(body))
                tokens.append(.lineBreak)
                continue
            }

            tokens.append(contentsOf: parseInline(line))
            tokens.append(.lineBreak)
        }

        if inCodeBlock {
            tokens.append(.codeBlock(language: codeLang, content: codeBuffer.joined(separator: "\n")))
        }

        if verbose { print("[MarkdownLexer] \(tokens.count) tokens") }
        return tokens
    }

    private func capture(_ s: String, _ m: NSTextCheckingResult, _ idx: Int) -> String {
        let ns = s as NSString
        if m.range(at: idx).location == NSNotFound { return "" }
        return ns.substring(with: m.range(at: idx))
    }

    private func parseInline(_ text: String) -> [MarkdownToken] {
        var tokens: [MarkdownToken] = []

        let pattern = #"""
        (\s+)                                   |  # 1 ws
        \!\[([^\]]*)\]\(([^)\s]+)\)            |  # 2/3 image
        \[([^\]]+)\]\(([^)\s]+)\)              |  # 4/5 link
        \~\~(.+?)\~\~                          |  # 6 strike
        \*\*(.+?)\*\*                          |  # 7 bold
        \*(.+?)\*                              |  # 8 italic
        \_(.+?)\_                              |  # 9 italic (underscore)
        \`([^`]+)\`                            |  # 10 code span
        ([^!\[\]\(\)\*\_`\s][^!\[\]\(\)\*`\n]*?)   # 11 plain
        """#

        let re = try! NSRegularExpression(pattern: pattern, options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators])
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(0..<ns.length))

        for m in matches {
            if let r = Range(m.range(at: 1), in: text) {
                tokens.append(.whitespace(String(text[r])))
            } else if let alt = Range(m.range(at: 2), in: text), let url = Range(m.range(at: 3), in: text) {
                tokens.append(.image(alt: String(text[alt]), url: String(text[url])))
            } else if let t = Range(m.range(at: 4), in: text), let u = Range(m.range(at: 5), in: text) {
                tokens.append(.link(text: String(text[t]), url: String(text[u])))
            } else if let r = Range(m.range(at: 6), in: text) {
                tokens.append(.strikethrough(String(text[r])))
            } else if let r = Range(m.range(at: 7), in: text) {
                tokens.append(.bold(String(text[r])))
            } else if let r = Range(m.range(at: 8), in: text) {
                tokens.append(.italic(String(text[r])))
            } else if let r = Range(m.range(at: 9), in: text) {
                tokens.append(.italic(String(text[r])))
            } else if let r = Range(m.range(at: 10), in: text) {
                tokens.append(.codeSpan(String(text[r])))
            } else if let r = Range(m.range(at: 11), in: text) {
                tokens.append(.plain(String(text[r])))
            }
        }
        return tokens
    }
}
