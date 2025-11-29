import Foundation

extension Prebuilt {
    public struct HTMLCheckbox: Equatable, Sendable, Hashable, Codable {
        public let isChecked: Bool

        public init(_ value: String?, config: HTMLCheckboxParser.Configuration = .init()) throws {
            self = try HTMLCheckboxParser.parse(value, config: config)
        }

        internal init(checked: Bool) {
            self.isChecked = checked
        }
    }

    public enum HTMLCheckboxParserError: Error, LocalizedError, Sendable, Equatable {
        case invalidValue(String)

        public var errorDescription: String? {
            switch self {
            case .invalidValue(let s):
                return "Invalid checkbox value '\(s)'"
            }
        }
    }

    public struct HTMLCheckboxParser: Sendable, Hashable {
        public struct Configuration: Sendable, Hashable {
            /// If true: unknown strings become false (lenient).
            /// If false: unknown strings throw (strict).
            public var unknownIsFalse: Bool

            public init(unknownIsFalse: Bool = false) {
                self.unknownIsFalse = unknownIsFalse
            }
        }

        public static func parse(_ input: String?, config: Configuration = .init()) throws -> HTMLCheckbox {
            guard let raw = Prebuilt.normalizeOptional(input) else {
                return HTMLCheckbox(checked: false)
            }

            let v = raw.lowercased()

            switch v {
            case "on", "true", "1", "yes", "checked":
                return HTMLCheckbox(checked: true)
            case "off", "false", "0", "no":
                return HTMLCheckbox(checked: false)
            default:
                if config.unknownIsFalse {
                    return HTMLCheckbox(checked: false)
                }
                throw HTMLCheckboxParserError.invalidValue(raw)
            }
        }
    }
}
