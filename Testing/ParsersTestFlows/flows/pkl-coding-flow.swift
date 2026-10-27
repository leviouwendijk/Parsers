import Foundation
import Parsers
import Testing

extension ParserTestSuite {
    static let pklCodingSuite = TestSuite(
        "pkl.coding.native",
        title: "Native Pkl Decodable mapping",
        tags: ["parsers", "pkl", "codable"]
    ) {
        Test("synthesized nested models, raw enums, UUID, collections and dictionaries") {
            struct Version: Decodable {
                let major: Int
                let minor: Int
                let patch: Int
            }
            enum Kind: String, Decodable { case binary, script }
            struct Config: Decodable {
                let uuid: UUID
                let name: String
                let kinds: [Kind]
                let versions: Version
                let arguments: [String]
                let flags: [Bool]
                let counts: [String: Int]
                let optional: String?
            }
            let text = """
                uuid = "2D45ED1F-3F26-4C11-93D1-BB92E9C1A734"
                name = "demo"
                kinds { "binary" "script" }
                versions { major = 1 minor = 2 patch = 3 }
                arguments { "-O" "-g" }
                flags = [true, false]
                counts { first = 12 second = 24 }
                """
            let decoded = try PklCoding().decode(Config.self, from: text)
            try Expect.equal(decoded.uuid.uuidString, "2D45ED1F-3F26-4C11-93D1-BB92E9C1A734", "pkl.coding.uuid")
            try Expect.equal(decoded.name, "demo", "pkl.coding.string")
            try Expect.equal(decoded.kinds, [.binary, .script], "pkl.coding.raw-enums")
            try Expect.equal(decoded.versions.patch, 3, "pkl.coding.nested")
            try Expect.equal(decoded.arguments, ["-O", "-g"], "pkl.coding.brace-array")
            try Expect.equal(decoded.flags, [true, false], "pkl.coding.bracket-array")
            try Expect.equal(decoded.counts, ["first": 12, "second": 24], "pkl.coding.dictionary")
            try Expect.equal(decoded.optional == nil, true, "pkl.coding.optional-missing")
        }

        Test("empty braces decode according to requested type") {
            struct Config: Decodable {
                let metadata: [String: Int]
                let arguments: [String]
            }
            let decoded = try PklCoding().decode(
                Config.self,
                from: "metadata {} arguments {}"
            )
            try Expect.equal(decoded.metadata.isEmpty, true, "pkl.coding.empty-object")
            try Expect.equal(decoded.arguments.isEmpty, true, "pkl.coding.empty-array")
        }

        Test("duplicate keys reject by default but can preserve legacy policies") {
            struct Value: Decodable { let name: String }
            let source = "name = \"first\" name = \"last\""
            var rejected = false
            do {
                _ = try PklCoding().decode(Value.self, from: source)
            } catch DecodingError.dataCorrupted(let context) {
                rejected = context.debugDescription.contains("Duplicate Pkl field")
            }
            try Expect.equal(rejected, true, "pkl.coding.duplicate-rejected")
            let first = try PklCoding(duplicateKeyStrategy: .firstWins).decode(Value.self, from: source)
            let last = try PklCoding(duplicateKeyStrategy: .lastWins).decode(Value.self, from: source)
            try Expect.equal(first.name, "first", "pkl.coding.first-wins")
            try Expect.equal(last.name, "last", "pkl.coding.last-wins")
        }

        Test("missing required field and incompatible type report coding path") {
            struct Value: Decodable { let name: String; let count: UInt8 }
            var missing = false
            do {
                _ = try PklCoding().decode(Value.self, from: "name = \"x\"")
            } catch DecodingError.keyNotFound(let key, _) {
                missing = key.stringValue == "count"
            }
            try Expect.equal(missing, true, "pkl.coding.missing-required")

            var mismatch = false
            do {
                _ = try PklCoding().decode(Value.self, from: "name = \"x\" count = \"bad\"")
            } catch DecodingError.typeMismatch(_, let context) {
                mismatch = context.codingPath.last?.stringValue == "count"
                    && context.debugDescription.contains("character range")
            }
            try Expect.equal(mismatch, true, "pkl.coding.mismatch-range")
        }

        Test("numeric conversion rejects integer overflow") {
            struct Value: Decodable { let count: UInt8 }
            var rejected = false
            do {
                _ = try PklCoding().decode(Value.self, from: "count = 256")
            } catch DecodingError.dataCorrupted(let context) {
                rejected = context.debugDescription.contains("overflows UInt8")
            }
            try Expect.equal(rejected, true, "pkl.coding.overflow")
        }

        Test("syntax failure is not disguised as model decoding failure") {
            struct Value: Decodable { let name: String }
            var rejected = false
            do {
                _ = try PklCoding().decode(Value.self, from: "name =")
            } catch is Pkl.SyntaxFailure {
                rejected = true
            }
            try Expect.equal(rejected, true, "pkl.coding.syntax-distinct")
        }

        Test("Foundation URL, Data, and Date strategies decode explicitly") {
            struct Resource: Decodable {
                let endpoint: URL
                let content: Data
                let published: Date
            }
            let text = """
                endpoint = "https://example.com/config"
                content = "SGVsbG8="
                published = "1970-01-01T00:00:00Z"
                """
            let value = try PklCoding().decode(Resource.self, from: text)
            try Expect.equal(value.endpoint.absoluteString, "https://example.com/config", "pkl.coding.url")
            try Expect.equal(String(data: value.content, encoding: .utf8), "Hello", "pkl.coding.data")
            try Expect.equal(value.published.timeIntervalSince1970, 0, "pkl.coding.iso-date")

            struct Timestamp: Decodable { let published: Date }
            let epoch = try PklCoding(dateDecodingStrategy: .secondsSince1970)
                .decode(Timestamp.self, from: "published = 0")
            try Expect.equal(epoch.published.timeIntervalSince1970, 0, "pkl.coding.epoch-date")
        }
    }
}
