import Position

public enum Pkl {
    public struct Entry: Sendable, Equatable {
        public let name: String
        public let value: Value
        /// Source character offsets, half-open, as defined by Position.
        public let range: PositionRange

        public init(
            name: String,
            value: Value,
            range: PositionRange
        ) {
            self.name = name
            self.value = value
            self.range = range
        }
    }

    public indirect enum Value: Sendable, Equatable {
        case string(String)
        case integer(Int)
        case boolean(Bool)
        case block([Entry])
        case collection([Value])
    }

    public struct Document: Sendable, Equatable {
        public let entries: [Entry]

        public init(entries: [Entry]) {
            self.entries = entries
        }

        /// Retain source order and duplicate keys for domain-specific validation.
        public func entries(named name: String) -> [Entry] {
            entries.filter { $0.name == name }
        }
    }
}
