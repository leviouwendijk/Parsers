import Foundation
import Position

/// Decodes the supported Pkl syntax tree through Swift Codable synthesis.
/// Semantic model defaults and legacy compatibility remain the consumer's responsibility.
public struct PklCoding: Sendable {
    public enum DuplicateKeyStrategy: Sendable {
        case reject
        case firstWins
        case lastWins
    }

    public enum DateDecodingStrategy: Sendable {
        case iso8601
        case secondsSince1970
    }

    public let duplicateKeyStrategy: DuplicateKeyStrategy
    public let dateDecodingStrategy: DateDecodingStrategy

    public init(
        duplicateKeyStrategy: DuplicateKeyStrategy = .reject,
        dateDecodingStrategy: DateDecodingStrategy = .iso8601
    ) {
        self.duplicateKeyStrategy = duplicateKeyStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
    }

    public func decode<T: Decodable>(_ type: T.Type, from source: String, filePath: String? = nil) throws -> T {
        try decode(type, from: Pkl.parse(source, filePath: filePath))
    }

    public func decode<T: Decodable>(_ type: T.Type, from document: Pkl.Document) throws -> T {
        try _PklDecoder(
            node: .init(value: .block(document.entries), range: nil),
            codingPath: [],
            duplicateKeyStrategy: duplicateKeyStrategy,
            dateDecodingStrategy: dateDecodingStrategy
        ).unbox(type)
    }
}

private struct _PklNode {
    let value: Pkl.Value
    let range: PositionRange?
}

private struct _PklIndexKey: CodingKey {
    let intValue: Int?
    let stringValue: String
    init(_ index: Int) { intValue = index; stringValue = String(index) }
    init?(intValue: Int) { self.init(intValue) }
    init?(stringValue: String) {
        guard let index = Int(stringValue) else { return nil }
        self.init(index)
    }
}

private struct _PklStringKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(_ value: String) { stringValue = value; intValue = Int(value) }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { self.init(String(intValue)) }
}

private struct _PklDecoder: Decoder {
    let node: _PklNode
    let codingPath: [CodingKey]
    let duplicateKeyStrategy: PklCoding.DuplicateKeyStrategy
    let dateDecodingStrategy: PklCoding.DateDecodingStrategy
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func typeMismatch(_ type: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(type, .init(
            codingPath: codingPath,
            debugDescription: "Expected \(type), found \(node.value)\(rangeDescription)"
        ))
    }

    var rangeDescription: String {
        guard let range = node.range else { return "" }
        return " at character range \(range.offsets)"
    }

    func corruption(_ message: String) -> DecodingError {
        DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: message + rangeDescription))
    }

    func child(_ value: Pkl.Value, range: PositionRange? = nil, key: CodingKey) -> Self {
        .init(node: .init(value: value, range: range), codingPath: codingPath + [key], duplicateKeyStrategy: duplicateKeyStrategy, dateDecodingStrategy: dateDecodingStrategy)
    }

    func unbox<T: Decodable>(_ type: T.Type) throws -> T {
        if type == URL.self {
            let text = try singleValueContainer().decode(String.self)
            guard let url = URL(string: text), let result = url as? T else {
                throw corruption("Invalid URL '\(text)'")
            }
            return result
        }
        if type == Data.self {
            let text = try singleValueContainer().decode(String.self)
            guard let data = Data(base64Encoded: text), let result = data as? T else {
                throw corruption("Invalid Base64 data")
            }
            return result
        }
        if type == Date.self {
            let date: Date
            switch dateDecodingStrategy {
            case .iso8601:
                let text = try singleValueContainer().decode(String.self)
                let formatter = ISO8601DateFormatter()
                guard let parsed = formatter.date(from: text) else {
                    throw corruption("Invalid ISO 8601 date '\(text)'")
                }
                date = parsed
            case .secondsSince1970:
                let seconds = try singleValueContainer().decode(Double.self)
                date = Date(timeIntervalSince1970: seconds)
            }
            guard let result = date as? T else {
                throw typeMismatch(type)
            }
            return result
        }
        return try T(from: self)
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .block(let entries) = node.value else { throw typeMismatch([String: Any].self) }
        return KeyedDecodingContainer(try _PklKeyedContainer<Key>(decoder: self, entries: entries))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let values: [Pkl.Value]
        switch node.value {
        case .collection(let elements): values = elements
        case .block(let entries) where entries.isEmpty: values = []
        default: throw typeMismatch([Any].self)
        }
        return _PklUnkeyedContainer(decoder: self, values: values)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        _PklSingleContainer(decoder: self)
    }
}

private struct _PklKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: _PklDecoder
    let entries: [String: Pkl.Entry]
    let allKeys: [Key]
    var codingPath: [CodingKey] { decoder.codingPath }

    init(decoder: _PklDecoder, entries raw: [Pkl.Entry]) throws {
        self.decoder = decoder
        var selected: [String: Pkl.Entry] = [:]
        var names: [String] = []
        for entry in raw {
            if selected[entry.name] != nil {
                switch decoder.duplicateKeyStrategy {
                case .reject:
                    throw decoder.child(entry.value, range: entry.range, key: _PklStringKey(entry.name))
                        .corruption("Duplicate Pkl field '\(entry.name)'")
                case .firstWins: continue
                case .lastWins: break
                }
            } else {
                names.append(entry.name)
            }
            selected[entry.name] = entry
        }
        self.entries = selected
        self.allKeys = names.compactMap(Key.init(stringValue:))
    }

    func contains(_ key: Key) -> Bool { entries[key.stringValue] != nil }
    func decodeNil(forKey key: Key) throws -> Bool {
        !contains(key)
    }

    private func require(_ key: Key) throws -> _PklDecoder {
        guard let entry = entries[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(
                codingPath: codingPath,
                debugDescription: "Missing Pkl field '\(key.stringValue)'"
            ))
        }
        return decoder.child(entry.value, range: entry.range, key: key)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try require(key).singleValueContainer().decode(type)
    }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try require(key).unbox(type)
    }
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        try require(key).container(keyedBy: type)
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try require(key).unkeyedContainer()
    }
    func superDecoder() throws -> Decoder {
        let key = _PklStringKey("super")
        if let entry = entries[key.stringValue] {
            return decoder.child(entry.value, range: entry.range, key: key)
        }
        return decoder.child(.block([]), key: key)
    }
    func superDecoder(forKey key: Key) throws -> Decoder { try require(key) }
}

private struct _PklUnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: _PklDecoder
    let values: [Pkl.Value]
    var currentIndex = 0
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }

    private mutating func take() throws -> _PklDecoder {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(Pkl.Value.self, .init(
                codingPath: codingPath + [_PklIndexKey(currentIndex)],
                debugDescription: "Unexpected end of Pkl collection"
            ))
        }
        let index = currentIndex
        currentIndex += 1
        return decoder.child(values[index], key: _PklIndexKey(index))
    }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(Pkl.Value.self, .init(
                codingPath: codingPath + [_PklIndexKey(currentIndex)],
                debugDescription: "Unexpected end of Pkl collection"
            ))
        }
        return false
    }
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: String.Type) throws -> String {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Double.Type) throws -> Double {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Float.Type) throws -> Float {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Int.Type) throws -> Int {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: UInt.Type) throws -> UInt {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try take().singleValueContainer().decode(type)
    }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try take().unbox(type)
    }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        try take().container(keyedBy: type)
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try take().unkeyedContainer()
    }
    mutating func superDecoder() throws -> Decoder { try take() }
}

private struct _PklSingleContainer: SingleValueDecodingContainer {
    let decoder: _PklDecoder
    var codingPath: [CodingKey] { decoder.codingPath }
    func decodeNil() -> Bool { false }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let value) = decoder.node.value else { throw decoder.typeMismatch(type) }
        return value
    }
    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .boolean(let value) = decoder.node.value else { throw decoder.typeMismatch(type) }
        return value
    }
    func decode(_ type: Int.Type) throws -> Int {
        guard case .integer(let value) = decoder.node.value else { throw decoder.typeMismatch(type) }
        return value
    }
    func decode(_ type: Int8.Type) throws -> Int8 {
        let integer = try decode(Int.self)
        guard let value = Int8(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows Int8") }
        return value
    }
    func decode(_ type: Int16.Type) throws -> Int16 {
        let integer = try decode(Int.self)
        guard let value = Int16(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows Int16") }
        return value
    }
    func decode(_ type: Int32.Type) throws -> Int32 {
        let integer = try decode(Int.self)
        guard let value = Int32(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows Int32") }
        return value
    }
    func decode(_ type: Int64.Type) throws -> Int64 {
        let integer = try decode(Int.self)
        guard let value = Int64(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows Int64") }
        return value
    }
    func decode(_ type: UInt.Type) throws -> UInt {
        let integer = try decode(Int.self)
        guard let value = UInt(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows UInt") }
        return value
    }
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let integer = try decode(Int.self)
        guard let value = UInt8(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows UInt8") }
        return value
    }
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let integer = try decode(Int.self)
        guard let value = UInt16(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows UInt16") }
        return value
    }
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let integer = try decode(Int.self)
        guard let value = UInt32(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows UInt32") }
        return value
    }
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let integer = try decode(Int.self)
        guard let value = UInt64(exactly: integer) else { throw decoder.corruption("Integer \(integer) overflows UInt64") }
        return value
    }
    func decode(_ type: Float.Type) throws -> Float {
        let integer = try decode(Int.self)
        return Float(integer)
    }
    func decode(_ type: Double.Type) throws -> Double {
        let integer = try decode(Int.self)
        return Double(integer)
    }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decoder.unbox(type)
    }
}

public extension Pkl.Document {
    func decode<T: Decodable>(
        _ type: T.Type,
        using coding: PklCoding = .init()
    ) throws -> T {
        try coding.decode(type, from: self)
    }
}
