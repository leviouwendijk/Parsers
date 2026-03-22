import Foundation
import Parsing

extension Prebuilt.Content {
    public enum Skip {
        public static func newlines() -> AnyTokenParser<Void> {
            AnyTokenParser<Void> { cursor in
                var cur = cursor

                guard let token = cur.peek() else {
                    return .failure(Diagnostic("expected newline"))
                }

                guard case .newline = token else {
                    return .failure(Diagnostic("expected newline"))
                }

                cur.advance()
                return .success((), cur)
            }
        }

        public static func whitespace() -> AnyTokenParser<Void> {
            AnyTokenParser<Void> { cursor in
                var cur = cursor

                guard let token = cur.peek() else {
                    return .failure(Diagnostic("expected whitespace"))
                }

                guard case .whitespace = token else {
                    return .failure(Diagnostic("expected whitespace"))
                }

                cur.advance()
                return .success((), cur)
            }
        }

        public static func comments() -> AnyTokenParser<Void> {
            AnyTokenParser<Void> { cursor in
                var cur = cursor

                guard let token = cur.peek() else {
                    return .failure(Diagnostic("expected comment"))
                }

                switch token {
                    case .comment_line, .comment_block:
                        cur.advance()
                        return .success((), cur)

                    default:
                        return .failure(Diagnostic("expected comment"))
                }
            }
        }

        public static func commentsAndNewlines() -> AnyTokenParser<Void> {
            comments()
                .orElse(newlines())
        }

        public static func trivia() -> AnyTokenParser<Void> {
            whitespace()
                .orElse(comments())
                .orElse(newlines())
        }

        @available(*, message: "don't use, use trivia()")
        public static func accountingLike() -> AnyTokenParser<Void> {
            trivia()
        }
    }
}
