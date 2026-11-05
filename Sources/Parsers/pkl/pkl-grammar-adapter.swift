import Foundation
import GrammarParsing
import Parsing
import Position

public extension Pkl {
    /// Canonical grammar-backed parsing, exposed alongside Pkl.Parser for differential testing.
    static func parseCanonical(_ source: String, filePath: String? = nil) throws -> Document {
        let root: GrammarParser.Node
        do {
            root = try parseGrammarTree(source, filePath: filePath)
        } catch GrammarParser.Failure.syntax(let diagnostic) {
            throw SyntaxFailure(diagnostic)
        } catch GrammarParser.Failure.lexical(let error) {
            let range = try? Position.TextMap(source: source).legacyRange(error.range)
            throw SyntaxFailure(Diagnostic(error.message, range: range, utf8Range: error.range))
        }
        return Document(entries: try GrammarDocumentAdapter(source: source).entries(in: root))
    }
}

private struct GrammarDocumentAdapter {
    let source: String
    let textMap: Position.TextMap

    init(source: String) {
        self.source = source
        self.textMap = Position.TextMap(source: source)
    }

    func entries(in node: GrammarParser.Node) throws -> [Pkl.Entry] {
        try node.children.filter { $0.name == "entry" }.map(entry)
    }

    func entry(_ node: GrammarParser.Node) throws -> Pkl.Entry {
        guard let name = node.children.first(where: { $0.field == "name" })?.text,
              let valueNode = node.children.first(where: { $0.field == "value" }) else {
            throw failure("Missing Pkl entry field", at: node)
        }
        return Pkl.Entry(name: name, value: try value(valueNode), range: try textMap.legacyRange(node.range))
    }

    func value(_ node: GrammarParser.Node) throws -> Pkl.Value {
        switch node.name {
        case "value", "element":
            guard let child = node.children.first else {
                throw failure("Missing Pkl value", at: node)
            }
            return try value(child)
        case "quoted":
            guard let raw = node.text else { throw failure("Missing quoted source", at: node) }
            return .string(unescape(raw))
        case "number":
            guard let raw = node.text, let integer = Int(raw) else {
                throw failure("Expected an integer", at: node)
            }
            return .integer(integer)
        case "negative":
            guard let raw = node.children.first(where: { $0.name == "number" })?.text,
                  let integer = Int("-" + raw) else {
                throw failure("Expected integer after '-'", at: node)
            }
            return .integer(integer)
        case "boolean":
            guard let raw = node.children.first?.text, raw == "true" || raw == "false" else {
                throw failure("Expected boolean literal", at: node)
            }
            return .boolean(raw == "true")
        case "brace":
            if let entriesNode = node.children.first(where: { $0.name == "object_entries" }) {
                return .block(try entries(in: entriesNode))
            }
            if let elementsNode = node.children.first(where: { $0.name == "elements" }) {
                return .collection(try elements(in: elementsNode))
            }
            return .block([])
        case "array":
            return .collection(try elements(in: node))
        default:
            throw failure("Unexpected Pkl grammar node '\(node.name)'", at: node)
        }
    }

    func elements(in node: GrammarParser.Node) throws -> [Pkl.Value] {
        try node.children.filter { $0.name == "element" }.map(value)
    }

    func failure(_ message: String, at node: GrammarParser.Node) -> Pkl.SyntaxFailure {
        let range = try? textMap.legacyRange(node.range)
        return Pkl.SyntaxFailure(Diagnostic(message, range: range, utf8Range: node.range))
    }

    /// Match Lexer's quoted-string unescaping: n, t, quote and backslash are special.
    /// Unknown backslash escapes retain their following scalar and drop the slash.
    func unescape(_ quoted: String) -> String {
        var scalars = Array(quoted.unicodeScalars)
        guard scalars.count >= 2 else { return quoted }
        scalars.removeFirst()
        scalars.removeLast()
        var decoded = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\\", index + 1 < scalars.count {
                index += 1
                switch scalars[index] {
                case "n": decoded.append("\n")
                case "t": decoded.append("\t")
                case "\"": decoded.append("\"")
                case "\\": decoded.append("\\")
                default: decoded.append(scalars[index])
                }
            } else {
                decoded.append(scalar)
            }
            index += 1
        }
        return String(decoded)
    }
}
