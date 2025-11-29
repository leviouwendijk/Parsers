import Foundation

extension Prebuilt {
    public struct HumanFullName: Equatable, Sendable, Hashable, Codable {
        public let rawValue: String

        public init(_ value: String) throws {
            self = try HumanFullNameParser.parse(value).asName()
        }

        public init(
            _ value: String?
        ) throws {
            guard let v = value else { 
                throw RawInputValueError.empty(Self.self)
            }
            try self.init(v)
        }

        internal init(validated rawValue: String) {
            self.rawValue = rawValue
        }

        fileprivate func asName() -> HumanFullName { self }
    }

    public struct HumanFullNameParser: Parser, Sendable {
        public typealias Output = HumanFullName

        public init() {}

        public func parse(_ cursor: Cursor) -> ParseResult<HumanFullName> {
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 2,
                maxLength: 128,
                collapseWhitespace: true,
                allowNewlines: false
            )

            switch NonEmptyTextParser(config: cfg).parse(cursor) {
            case .success(let t, let rest):
                return .success(HumanFullName(validated: t.rawValue), rest)
            case .failure(let d):
                return .failure(d)
            }
        }

        public static func parse(_ input: String) throws -> HumanFullName {
            let cfg = NonEmptyTextParser.Configuration(
                minLength: 2,
                maxLength: 128,
                collapseWhitespace: true,
                allowNewlines: false
            )
            let t = try NonEmptyTextParser.parse(input, config: cfg)
            return HumanFullName(validated: t.rawValue)
        }
    }
}
