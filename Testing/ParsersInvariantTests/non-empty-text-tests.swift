import Foundation
import Parsing
import Parsers
import Testing

private func test_default_normalization() throws {
    let value = try Prebuilt.NonEmptyText("  alpha   beta  ")
    try Expect.true(value.rawValue == "alpha beta", "default construction keeps normalized text")

    switch Prebuilt.NonEmptyTextParser().parse(Cursor("  alpha   beta  ")) {
    case .success(let parsed, let next):
        try Expect.true(parsed == value && next.isEOF, "protocol parser returns the same guaranteed value")
    case .failure(let diagnostic):
        try Expect.true(false, "unexpected parser failure: \(diagnostic)")
    }
}

private func test_configurable_normalization() throws {
    let config = Prebuilt.NonEmptyTextParser.Configuration(collapseWhitespace: false)
    let value = try Prebuilt.NonEmptyText("  alpha   beta  ", config: config)
    try Expect.true(value.rawValue == "alpha   beta", "disabled collapsing is preserved")

    switch Prebuilt.NonEmptyTextParser(config: config).parse(Cursor("  alpha   beta  ")) {
    case .success(let parsed, _):
        try Expect.true(parsed.rawValue == value.rawValue, "invariant construction must not re-normalize")
    case .failure(let diagnostic):
        try Expect.true(false, "unexpected configured parser failure: \(diagnostic)")
    }
}

private func test_intrinsic_invariant_and_empty_priority() throws {
    do {
        _ = try Prebuilt.NonEmptyText(.init(" \t "))
        try Expect.true(false, "blank Raw must fail invariant construction")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        try Expect.true(error == .empty, "typed intrinsic failure")
    }

    do {
        _ = try Prebuilt.NonEmptyText("   ", config: .init(minLength: 5))
        try Expect.true(false, "blank source must fail before minimum length")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        try Expect.true(error == .empty, "empty retains original diagnostic precedence")
    }

    switch Prebuilt.NonEmptyTextParser().optional().parse(Cursor("  ")) {
    case .success:
        try Expect.true(false, "optional cannot silently discard invalid recognized text")
    case .failure(let diagnostic):
        try Expect.true(diagnostic.committed && diagnostic.message == "Text cannot be empty", "semantic failure is committed")
    }
}

private func test_contextual_lengths() throws {
    let config = Prebuilt.NonEmptyTextParser.Configuration(minLength: 3, maxLength: 4)
    try Expect.true(try Prebuilt.NonEmptyText("abc", config: config).rawValue == "abc", "in-range text")

    do {
        _ = try Prebuilt.NonEmptyText("ab", config: config)
        try Expect.true(false, "too short must fail")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        try Expect.true(error == .tooShort(min: 3, actual: 2), "minimum remains contextual")
    }
    do {
        _ = try Prebuilt.NonEmptyText("abcde", config: config)
        try Expect.true(false, "too long must fail")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        try Expect.true(error == .tooLong(max: 4, actual: 5), "maximum remains contextual")
    }

    switch Prebuilt.NonEmptyTextParser(config: config).parse(Cursor("ab")) {
    case .success:
        try Expect.true(false, "parser must also reject contextually invalid text")
    case .failure(let diagnostic):
        try Expect.true(diagnostic.committed, "contextual failure must not be swallowed by combinators")
        try Expect.true(diagnostic.message == "Text is too short (min 3, got 2)", "error wording retained")
        try Expect.true(diagnostic.range?.start.offset == 0 && diagnostic.range?.end.offset == 2, "consumed range retained")
    }
}

private func test_bad_character() throws {
    let input = "ok\u{0001}"
    do {
        _ = try Prebuilt.NonEmptyText(input)
        try Expect.true(false, "control character must fail")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        guard case .invalidCharacter(let character, _) = error else {
            try Expect.true(false, "wrong typed character error")
            return
        }
        try Expect.true(character == "\u{0001}", "offending character retained")
    }
}

private func test_codable_validation() throws {
    let original = try Prebuilt.NonEmptyText("a   b")
    let encoded = try JSONEncoder().encode(original)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: String]
    try Expect.true(object?["rawValue"] == "a b", "existing keyed Codable representation retained")

    let restored = try JSONDecoder().decode(Prebuilt.NonEmptyText.self, from: encoded)
    try Expect.true(restored == original, "valid values roundtrip")

    do {
        _ = try JSONDecoder().decode(
            Prebuilt.NonEmptyText.self,
            from: Data(#"{"rawValue":"   "}"#.utf8)
        )
        try Expect.true(false, "decoding cannot bypass intrinsic guarantee")
    } catch is DecodingError {
        // Expected: invalid decoded representation.
    }
}

private func test_optional_raw_input() throws {
    let absent: String? = nil
    do {
        _ = try Prebuilt.NonEmptyText(absent)
        try Expect.true(false, "nil input must fail")
    } catch let error as Prebuilt.RawInputValueError {
        guard case .empty = error else {
            try Expect.true(false, "raw input still uses existing error")
            return
        }
    }
}

public enum ParsersInvariantTestsSuite {
    public static let suite = TestSuite(
        "parsers-invariant",
        title: "Prebuilt invariant tests",
        tags: ["parsers", "invariant"]
    ) {
        Test("nonempty-default", tags: ["nonempty"]) { try test_default_normalization() }
        Test("nonempty-config", tags: ["nonempty"]) { try test_configurable_normalization() }
        Test("nonempty-intrinsic", tags: ["nonempty"]) { try test_intrinsic_invariant_and_empty_priority() }
        Test("nonempty-limits", tags: ["nonempty"]) { try test_contextual_lengths() }
        Test("nonempty-characters", tags: ["nonempty"]) { try test_bad_character() }
        Test("nonempty-codable", tags: ["nonempty"]) { try test_codable_validation() }
        Test("nonempty-nil", tags: ["nonempty"]) { try test_optional_raw_input() }
        Test("nonempty-newlines", tags: ["nonempty"]) { try test_nonempty_newlines() }
        Test("email-valid", tags: ["email"]) { try test_email_valid() }
        Test("email-invalid", tags: ["email"]) { try test_email_invalid() }
        Test("email-diagnostics", tags: ["email"]) { try test_email_diagnostics() }
        Test("email-codable", tags: ["email"]) { try test_email_codable() }
        Test("email-optional-input", tags: ["email"]) { try test_email_optional_input() }
        Test("bounded-limits", tags: ["numeric"]) { try test_bounded_integer_limits() }
        Test("bounded-overflow", tags: ["numeric"]) { try test_bounded_integer_overflow() }
        Test("bounded-invalid", tags: ["numeric"]) { try test_bounded_integer_invalid() }
        Test("date-block-valid", tags: ["numeric", "date"]) { try test_date_block_valid() }
        Test("date-block-fractional", tags: ["numeric", "date"]) { try test_date_block_fractional() }
        Test("date-block-overflow", tags: ["numeric", "date"]) { try test_date_block_overflow() }
    }
}
