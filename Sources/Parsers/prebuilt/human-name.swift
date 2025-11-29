import Foundation

extension Prebuilt {
    public struct HumanName: Equatable, Sendable, Hashable {
        public let rawValue: String

        public init(_ value: String) throws {
            self = try HumanNameParser.parse(value).asName()
        }

        internal init(validated rawValue: String) {
            self.rawValue = rawValue
        }

        fileprivate func asName() -> HumanName { self }
    }

    public struct HumanNameParser: Parser, Sendable {
        public typealias Output = HumanName

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<HumanName> {
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 2,
                maxLength: 128,
                collapseWhitespace: true,
                allowNewlines: false
            )

            switch NonEmptyTextParser(config: cfg).parse(cursor) {
            case .success(let t, let rest):
                return .success(HumanName(validated: t.rawValue), rest)
            case .failure(let d):
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> HumanName {
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 2,
                maxLength: 128,
                collapseWhitespace: true,
                allowNewlines: false
            )
            let t = try NonEmptyTextParser.parse(input, config: cfg)
            return HumanName(validated: t.rawValue)
        }
    }
}
