import Foundation

public enum Prebuilt {
    @inline(__always)
    static func badScalar(_ s: Unicode.Scalar) -> Bool {
        CharacterSet.whitespacesAndNewlines.contains(s) || isControlScalar(s)
    }

    @inline(__always)
    static func isControlScalar(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return v < 0x20 || v == 0x7F || (0x80...0x9F).contains(v)
    }

    static func loc(in input: String, offset: Int) -> SourceLocation? {
        var line = 1
        var col = 1
        var i = 0

        for ch in input {
            if i >= offset { break }
            if ch == "\n" {
                line += 1
                col = 1
            } else {
                col += 1
            }
            i += 1
        }

        return SourceLocation(file: nil, line: line, column: col, invocation: nil)
    }

    @inline(__always)
    static func invalid(_ ch: Character, input: String, offset: Int) -> EmailParserError {
        .invalidCharacter(ch, location: loc(in: input, offset: offset))
    }

    public static func normalizeOptional(_ s: String?) -> String? {
        let trimmed = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func normalizeOptional(_ s: [String]?) -> [String]? {
        guard let strings = s else { return nil }
        let normalized =  strings.compactMap { normalizeOptional($0) }
        return normalized.isEmpty ? nil : normalized
   }
}
