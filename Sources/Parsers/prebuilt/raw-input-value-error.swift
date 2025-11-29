import Foundation

extension Prebuilt {
    public enum RawInputValueError: Error, LocalizedError, Sendable, Equatable {
        case empty(typeName: String)

        public static func empty<T>(_ type: T.Type) -> Self {
            .empty(typeName: String(reflecting: type))
        }

        public var errorDescription: String? {
            switch self {
            case let .empty(typeName):
                return "Passed raw input value for \(typeName) cannot be empty"
            }
        }
    }
}
