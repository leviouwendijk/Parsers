import Foundation
import plate
import Extensions

public struct NorgLexerOptions {
    public let trimLeadingNewlines: Bool
    public let trimTrailingNewlines: Bool
    
    public init(
        trimLeadingNewlines: Bool = false,
        trimTrailingNewlines: Bool = false
    ) {
        self.trimLeadingNewlines = trimLeadingNewlines
        self.trimTrailingNewlines = trimTrailingNewlines
    }
}

public struct NorgLexer {
    public let text: String
    public let options: NorgLexerOptions
    public let verbose: Bool

    public init(
        text: String,
        options: NorgLexerOptions = NorgLexerOptions(),
        verbose: Bool = false
    ) {
        self.text = text
        self.options = options
        self.verbose = verbose
    }

    public init(
        file: String,
        options: NorgLexerOptions = NorgLexerOptions(),
        verbose: Bool = false
    ) throws {
        self.text = try readFile(at: file)
        self.options = options
        self.verbose = verbose
    }

    public func tokenize() -> [NorgToken] {
        var tokens: [NorgToken] = []

        let cleaned = text.strippingNorgMetadata
        let formatted = cleaned.emDashedFromHyphens()
        var lines = formatted.splitByNewlines

        if options.trimLeadingNewlines {
            while let first = lines.first,
                  first.trimmingCharacters(in: .whitespaces).isEmpty
            {
                lines.removeFirst()
            }
        }

        if options.trimTrailingNewlines {
            while let last = lines.last,
                  last.trimmingCharacters(in: .whitespaces).isEmpty
            {
                lines.removeLast()
            }
        }


        if verbose { print("[VERBOSE] Split into \(lines.count) lines") }

        var isMulti = false
        var multiTitle = ""
        var multiContent = ""
        var pendingSingle: String? = nil

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if verbose { print("[VERBOSE] Line: \(line)") }

            if isMulti {
                if line.starts(with: "^^") {
                    tokens.append(
                        .multiFootnote(
                            multiTitle,
                            multiContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                    isMulti = false; multiTitle = ""; multiContent = ""
                } else {
                    multiContent += line + "\n"
                }
                continue
            }

            if let title = pendingSingle {
                if !line.starts(with: "^") {
                    tokens.append(.singleFootnote(title, line))
                    pendingSingle = nil
                    continue
                }
            }

            if line.isEmpty {
                tokens.append(.emptyLine)
                continue
            } else if let hdr = matchHeader(line) {
                tokens.append(.header(hdr))
            } else if let foot = matchFootnote(line) {
                switch foot {
                case .singleFootnote(let t, _):
                    pendingSingle = t
                case .multiFootnote(let t, let c):
                    isMulti = true; multiTitle = t; multiContent = c + "\n"
                default:
                    tokens.append(foot)
                }
            }
            else {
                let inline = parseInlineFormatting(line, verbose: verbose)
                tokens.append(contentsOf: inline)
            }

            tokens.append(.lineBreak) // adding linebreaks
        }

        if isMulti {
            tokens.append(
                .multiFootnote(
                    multiTitle,
                    multiContent.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        if verbose { print("[VERBOSE] Done, \(tokens.count) tokens") }

        return tokens
    }

    private func matchHeader(_ line: String) -> String? {
        let re = try! NSRegularExpression(pattern: #"^(\*{1,7}) (.+)"#)
        let ns = line as NSString
        if let m = re.firstMatch(in: line, range: NSRange(0..<ns.length)) {
            return ns.substring(with: m.range(at: 2))
        }
        return nil
    }

    private func matchFootnote(_ line: String) -> NorgToken? {
        let single = try! NSRegularExpression(pattern: #"^\^\s*(\d+)$"#)
        let multiStart = try! NSRegularExpression(pattern: #"^\^\^\s*(\d+)\s*(.+)?$"#)
        let multiEnd = try! NSRegularExpression(pattern: #"^\^\^$"#)
        let ns = line as NSString

        if let m = single.firstMatch(in: line, range: NSRange(0..<ns.length)) {
            return .singleFootnote(
                ns.substring(with: m.range(at: 1)),
                ""
            )
        }
        if let m = multiStart.firstMatch(in: line, range: NSRange(0..<ns.length)) {
            let title = ns.substring(with: m.range(at: 1))
            let content = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : ""
            return .multiFootnote(title, content)
        }
        if multiEnd.firstMatch(in: line, range: NSRange(0..<ns.length)) != nil {
            return .multiFootnote("END_MULTI", "")
        }
        return nil
    }

    private func parseInlineFormatting(_ text: String, verbose: Bool) -> [NorgToken] {
        var tokens: [NorgToken] = []
        let pattern = #"""
        (\s+)                |   # 1: whitespace runs
        \*(.*?)\*            |   # 2: *bold*
        \/(.*?)\/            |   # 3: /italic/
        \{\^ (\d+)\}         |   # 4: {^1} inline footnote
        (--|—)               |   # 5: em dash
        (['"])(.*?)\6        |   # 6/7: quotes
        (\b\w+'\w+\b)        |   # 8: contraction
        ([^\s*\/{]+)            # 9: other plaintext
        """#
        let re = try! NSRegularExpression(
            pattern: pattern,
            options: [.allowCommentsAndWhitespace]
        )
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(0..<ns.length))

        for m in matches {
            if let r = Range(m.range(at: 1), in: text) {
                tokens.append(.whitespace(String(text[r])))
            }
            else if let r = Range(m.range(at: 2), in: text) {
                tokens.append(.bold(String(text[r])))
            }
            else if let r = Range(m.range(at: 3), in: text) {
                tokens.append(.italic(String(text[r])))
            }
            else if let r = Range(m.range(at: 4), in: text) {
                tokens.append(.inlineFootnoteReference(String(text[r])))
            }
            else if m.range(at: 5).location != NSNotFound {
                tokens.append(.plain("—"))
            }
            else if let qt = Range(m.range(at: 6), in: text),
                    let qc = Range(m.range(at: 7), in: text) {
                let quoteChar = text[qt] == "\"" ? "“" : "‘"
                let quote      = "\(quoteChar)\(text[qc])\(quoteChar == "“" ? "”" : "’")"
                tokens.append(.plain(quote))
            }
            else if let r = Range(m.range(at: 8), in: text) {
                tokens.append(.plain(text[r].replacingOccurrences(of: "'", with: "’")))
            }
            else if let r = Range(m.range(at: 9), in: text) {
                tokens.append(.plain(String(text[r])))
            }
        }

        return tokens
    }
}
