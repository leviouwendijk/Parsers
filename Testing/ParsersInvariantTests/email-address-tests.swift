import Foundation
import Parsing
import Parsers
import Testing

func test_nonempty_newlines() throws {
    let defaultValue = try Prebuilt.NonEmptyText("first\nsecond")
    try Expect.true(defaultValue.rawValue == "first second", "newlines collapse under the default policy")

    let preserve = Prebuilt.NonEmptyTextParser.Configuration(
        collapseWhitespace: false,
        allowNewlines: true
    )
    let preserved = try Prebuilt.NonEmptyText("first\r\nsecond", config: preserve)
    try Expect.true(preserved.rawValue == "first\r\nsecond", "CRLF is preserved when collapsing is disabled")

    let forbidden = Prebuilt.NonEmptyTextParser.Configuration(allowNewlines: false)
    do {
        _ = try Prebuilt.NonEmptyText("first\nsecond", config: forbidden)
        try Expect.true(false, "disallowed LF must be rejected")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        guard case .invalidCharacter(let ch, _) = error else {
            try Expect.true(false, "expected invalidCharacter for LF")
            return
        }
        try Expect.true(ch == "\n", "LF error retains the offending character")
    }
    do {
        _ = try Prebuilt.NonEmptyText("first\r\nsecond", config: forbidden)
        try Expect.true(false, "disallowed CRLF must be rejected")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        guard case .invalidCharacter(let ch, _) = error else {
            try Expect.true(false, "expected invalidCharacter for CRLF")
            return
        }
        try Expect.true(ch == "\r\n", "CRLF error retains the offending character")
    }
    do {
        _ = try Prebuilt.NonEmptyText("valid\u{0001}text")
        try Expect.true(false, "unrelated controls remain invalid")
    } catch let error as Prebuilt.NonEmptyTextParserError {
        guard case .invalidCharacter = error else {
            try Expect.true(false, "control-character error remains typed")
            return
        }
    }
}

func test_email_valid() throws {
    let input = "first.last+tag@Sub.Example.com"
    let constructed = try Prebuilt.EmailAddress(input)
    let parsed = try Prebuilt.EmailParser.parse(input)
    try Expect.true(constructed == parsed, "String construction and static parsing agree")
    try Expect.true(constructed.rawValue == input, "original capitalization and punctuation are preserved")

    switch Prebuilt.EmailParser().parse(Cursor(input)) {
    case .success(let value, let remainder):
        try Expect.true(value == constructed, "parser returns the intrinsic invariant type")
        try Expect.true(remainder.isEOF, "successful parsing consumes the input")
    case .failure(let diagnostic):
        try Expect.true(false, "unexpected email parser error: \(diagnostic)")
    }
}

func test_email_invalid() throws {
    for text in [
        "without-at", "@example.com", "local@", "local@example",
        "a..b@example.com", "a@-example.com", "a@example..com",
        "a@example.com\n", "a@domain.com-"
    ] {
        do {
            _ = try Prebuilt.EmailAddress(text)
            try Expect.true(false, "invalid email must fail: \(text)")
        } catch is Prebuilt.EmailParserError {
            // An invalid email must fail with the existing typed error family.
        }
    }
    do {
        _ = try Prebuilt.EmailAddress("without-at")
        try Expect.true(false, "missing @ must be rejected")
    } catch let error as Prebuilt.EmailParserError {
        try Expect.true(error == .missingAt, "the original missingAt case is retained")
    }
    do {
        _ = try Prebuilt.EmailAddress("local@example")
        try Expect.true(false, "domain without a dot must be rejected")
    } catch let error as Prebuilt.EmailParserError {
        try Expect.true(error == .emptyDomain, "the original emptyDomain case is retained")
    }
}

func test_email_diagnostics() throws {
    let input = "a@valid.com\u{0001}"
    switch Prebuilt.EmailParser().parse(Cursor(input)) {
    case .success:
        try Expect.true(false, "invalid control character must fail")
    case .failure(let diagnostic):
        try Expect.true(diagnostic.committed, "a recognized invalid email must be committed")
        try Expect.true(diagnostic.range?.start.offset == 0 && diagnostic.range?.end.offset == input.count - 1, "scanner span ends at the offending character")
        try Expect.true(diagnostic.message.contains("Invalid character"), "source error is preserved")
    }

    switch Prebuilt.EmailParser().optional().parse(Cursor("without-at")) {
    case .success:
        try Expect.true(false, "an invalid recognized email must not become absent")
    case .failure(let diagnostic):
        try Expect.true(diagnostic.committed && diagnostic.message == "Missing '@'", "semantic invariant failure propagates")
    }
}

func test_email_codable() throws {
    let original = try Prebuilt.EmailAddress("person@example.com")
    let encoded = try JSONEncoder().encode(original)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: String]
    try Expect.true(object?["rawValue"] == original.rawValue, "existing keyed rawValue encoding is retained")
    try Expect.true(try JSONDecoder().decode(Prebuilt.EmailAddress.self, from: encoded) == original, "valid decoded email roundtrips")

    for payload in [#"{"rawValue":"without-at"}"#, #"{"rawValue":"a@example..com"}"#] {
        do {
            _ = try JSONDecoder().decode(Prebuilt.EmailAddress.self, from: Data(payload.utf8))
            try Expect.true(false, "invalid encoded value cannot bypass validation")
        } catch is DecodingError {
            // Expected.
        }
    }
}

func test_email_optional_input() throws {
    let absent: String? = nil
    do {
        _ = try Prebuilt.EmailAddress(absent)
        try Expect.true(false, "nil input must fail")
    } catch let error as Prebuilt.RawInputValueError {
        guard case .empty = error else {
            try Expect.true(false, "existing nil-input error must be retained")
            return
        }
    }
}
