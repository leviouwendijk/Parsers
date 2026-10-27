import Foundation
import Parsing
import Parsers
import Testing

func test_bounded_integer_limits() throws {
    let maximum = try Prebuilt.BoundedIntegerParser.parse(
        String(Int.max),
        range: 0...Int.max
    )
    try Expect.true(maximum.rawValue == Int.max, "Int.max is accepted without overflow")

    let zero = try Prebuilt.BoundedIntegerParser.parse("  000 \n", range: 0...0)
    try Expect.true(zero.rawValue == 0, "zero and leading zeros remain accepted")

    let bounded = try Prebuilt.BoundedIntegerParser.parse("10", range: 10...10)
    try Expect.true(bounded.rawValue == 10, "inclusive range boundaries remain valid")
}

func test_bounded_integer_overflow() throws {
    for source in [String(Int.max) + "0", String(repeating: "9", count: 100)] {
        do {
            _ = try Prebuilt.BoundedIntegerParser.parse(source, range: 0...Int.max)
            try Expect.true(false, "oversized numeric input must not parse: \(source)")
        } catch let error as Prebuilt.BoundedIntegerParserError {
            try Expect.true(error == .overflow, "overflow must be a typed error, not a trap")
        }
    }
}

func test_bounded_integer_invalid() throws {
    do {
        _ = try Prebuilt.BoundedIntegerParser.parse("11", range: 0...10)
        try Expect.true(false, "ordinary bound failure must still be reported")
    } catch let error as Prebuilt.BoundedIntegerParserError {
        try Expect.true(
            error == .outOfRange(min: 0, max: 10, actual: 11),
            "out-of-range errors preserve the bounds and actual value"
        )
    }

    for source in ["-1", "1.5", "5\u{0301}"] {
        do {
            _ = try Prebuilt.BoundedIntegerParser.parse(source, range: 0...10)
            try Expect.true(false, "invalid character input must not parse: \(source)")
        } catch let error as Prebuilt.BoundedIntegerParserError {
            guard case .invalidCharacter = error else {
                try Expect.true(false, "bad characters must retain invalidCharacter errors")
                continue
            }
        }
    }
}

private func parseNumericDateBlock(_ source: String) -> TokenParseResult<Prebuilt.Content.DateBlockParser.Output> {
    var options = LexerOptions()
    options.emit_whitespace = false
    options.emit_newlines = false
    options.emit_comments = false

    var lexer = Lexer(
        source: source,
        sets: LexingSets(keywords: []),
        options: options
    )
    return Prebuilt.Content.DateBlockParser(
        assignment: Prebuilt.Content.Assignment.equals(),
        skip: Prebuilt.Content.Skip.trivia()
    ).parse(TokenCursor(lexedTokens: lexer.lexedTokens(), source: source))
}

func test_date_block_valid() throws {
    switch parseNumericDateBlock("year = 2024 month = 2 day = 29") {
    case .success(let value, let remainder):
        try Expect.true(value.year == 2024 && value.month == 2 && value.day == 29,
                        "valid date values preserve exact integer components")
        try Expect.true(remainder.isEOF, "date block consumes all its input")
    case .failure(let diagnostic):
        try Expect.true(false, "valid date must parse: \(diagnostic)")
    }
}

func test_date_block_fractional() throws {
    switch parseNumericDateBlock("year = 2024 month = 1.5") {
    case .success:
        try Expect.true(false, "fractional date component must be rejected")
    case .failure(let diagnostic):
        try Expect.true(
            diagnostic.message == Prebuilt.Content.DateBlockParserError
                .expectedIntegerValue("month").localizedDescription,
            "fractional values retain expectedIntegerValue"
        )
    }
}

func test_date_block_overflow() throws {
    // These Decimal values are representable as Decimal but not as a machine Int.
    for source in ["year = 9223372036854775808", "year = 18446744073709551616"] {
        switch parseNumericDateBlock(source) {
        case .success:
            try Expect.true(false, "out-of-range whole Decimal must be rejected: \(source)")
        case .failure(let diagnostic):
            try Expect.true(
                diagnostic.message == Prebuilt.Content.DateBlockParserError
                    .integerOutOfRange("year").localizedDescription,
                "whole Decimal overflow retains a specific typed diagnostic"
            )
        }
    }
}
