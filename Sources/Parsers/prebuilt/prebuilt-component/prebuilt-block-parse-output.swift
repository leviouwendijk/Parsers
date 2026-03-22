import Foundation

extension Prebuilt.Content {
    public struct BlockParseOutput<Prefix: Sendable, Content: Sendable>: Sendable {
        public let prefix: Prefix?
        public let content: Content

        public init(
            prefix: Prefix?,
            content: Content
        ) {
            self.prefix = prefix
            self.content = content
        }
    }
}
