import Foundation

public enum Token: Equatable, Sendable {
    // literals / identifiers
    case keyword(String)             // e.g. entry, debit, credit, details
    case identifier(String)          // e.g. entity, account, levi_ouwendijk
    case number(Decimal, raw: String) // 200.00
    case string(String)              // e.g. details { ... } or "..."
    case date_literal(String)        // "2025-02-03", "03/02/2025"

    // trivia 
    case whitespace(String)          // runs of space/tabs
    case comment_line(String)        // // ... or # ...
    case comment_block(String)       // /* ... */ (optionally nested)
    case newline                     // \n

    // punctuation / symbols
    case left_brace                  // {
    case right_brace                 // }
    case left_parenthesis            // (
    case right_parenthesis           // )
    case left_bracket                // [
    case right_bracket               // ]
    case less_than                   // <
    case greater_than                // >
    case arrow                       // ->
    case dot                         // .
    case equals                      // =
    case comma                       // ,
    case hash                        // #
    case dollar                      // $
    case forward_slash               // /
    case backward_slash              // \
    case double_quote                // "
    case single_quote                // '

    case eof

    // convenience text
    public func string() -> String {
        switch self {
        case .keyword(let k):             return k
        case .identifier(let i):          return i
        case .number(_ , let raw):        return raw
        case .string(let s):              return s
        case .date_literal(let d):        return d
        case .whitespace(let w):          return w
        case .comment_line(let s):        return s
        case .comment_block(let s):       return s
        case .newline:                    return "\n"
        case .left_brace:                 return "{"
        case .right_brace:                return "}"
        case .left_parenthesis:           return "("
        case .right_parenthesis:          return ")"
        case .left_bracket:               return "["
        case .right_bracket:              return "]"
        case .less_than:                  return "<"
        case .greater_than:               return ">"
        case .arrow:                      return "->"
        case .dot:                        return "."
        case .equals:                     return "="
        case .comma:                      return ","
        case .hash:                       return "#"
        case .dollar:                     return "$"
        case .forward_slash:              return "/"
        case .backward_slash:             return "\\"
        case .double_quote:               return "\""
        case .single_quote:               return "'"
        case .eof:                        return "\0"
        }
    }

    // quick classifiers
    public var is_trivia: Bool {
        switch self {
        case .whitespace, 
            .comment_line,
            .comment_block, 
            .newline:
            return true

        default: 
            return false
        }
    }
    public var is_punctuation: Bool {
        switch self {
        case .left_brace, .right_brace, .left_parenthesis, .right_parenthesis,
             .less_than, .greater_than,
             .left_bracket, .right_bracket, .arrow, .dot, .equals, .comma,
             .hash, .dollar, .forward_slash, .backward_slash,
             .double_quote, .single_quote: 
             return true

        default: 
            return false
        }
    }

    public func sameCase(as other: Token) -> Bool {
        switch (self, other) {
        case (.left_brace, .left_brace),
             (.right_brace, .right_brace),
             (.left_parenthesis, .left_parenthesis),
             (.right_parenthesis, .right_parenthesis),
             (.left_bracket, .left_bracket),
             (.right_bracket, .right_bracket),
             (.less_than, .greater_than),
             (.arrow, .arrow),
             (.dot, .dot),
             (.equals, .equals),
             (.comma, .comma),
             (.hash, .hash),
             (.dollar, .dollar),
             (.forward_slash, .forward_slash),
             (.backward_slash, .backward_slash),
             (.double_quote, .double_quote),
             (.single_quote, .single_quote),
             (.newline, .newline),
             (.eof, .eof): 
             return true

        case (.keyword, .keyword),
             (.identifier, .identifier),
             (.number, .number),
             (.string, .string),
             (.date_literal, .date_literal),
             (.whitespace, .whitespace),
             (.comment_line, .comment_line),
             (.comment_block, .comment_block): 
             return true

        default: 
            return false
        }
    }
}
