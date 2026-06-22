import Foundation
import Parsing

extension Prebuilt {
    public struct BoundedInteger: Equatable, Sendable, Hashable, Codable {
        public let rawValue: Int

        public init(
            _ value: Int,
            range: ClosedRange<Int>
        ) throws {
            guard range.contains(value) else {
                throw BoundedIntegerParserError.outOfRange(
                    min: range.lowerBound,
                    max: range.upperBound,
                    actual: value
                )
            }

            self.rawValue = value
        }
    }

    public enum BoundedIntegerParserError: Error, LocalizedError, Sendable, Equatable {
        case empty
        case invalidCharacter(Character)
        case outOfRange(min: Int, max: Int, actual: Int)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Integer cannot be empty"

            case .invalidCharacter(let character):
                return "Invalid integer character '\(character)'"

            case .outOfRange(let min, let max, let actual):
                return "Integer out of range \(min)...\(max), got \(actual)"
            }
        }
    }

    public struct BoundedIntegerParser: Sendable, Hashable {
        public let range: ClosedRange<Int>

        public init(
            range: ClosedRange<Int>
        ) {
            self.range = range
        }

        public static func parse(
            _ input: String,
            range: ClosedRange<Int>
        ) throws -> BoundedInteger {
            let trimmed = input.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !trimmed.isEmpty else {
                throw BoundedIntegerParserError.empty
            }

            var value = 0

            for character in trimmed {
                guard let scalar = character.unicodeScalars.first,
                      scalar.isASCII,
                      (48...57).contains(scalar.value)
                else {
                    throw BoundedIntegerParserError.invalidCharacter(character)
                }

                value = (value * 10) + Int(scalar.value - 48)
            }

            return try BoundedInteger(
                value,
                range: range
            )
        }
    }
}
