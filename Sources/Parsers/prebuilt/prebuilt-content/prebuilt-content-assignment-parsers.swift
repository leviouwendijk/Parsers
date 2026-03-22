import Foundation
import Parsing

extension Prebuilt.Content {
    public enum Assignment {
        public static func equals() -> AnyTokenParser<Void> {
            AnyTokenParser(Expect(.equals)).map { (_: Token) in () }
        }

        public static func colon() -> AnyTokenParser<Void> {
            AnyTokenParser(Expect(.colon)).map { (_: Token) in () }
        }

        public static func equalsOrColon() -> AnyTokenParser<Void> {
            equals().orElse(colon())
        }
    }
}
