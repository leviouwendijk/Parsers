import Testing

enum ParserTestSuite {
    static let suite = TestSuite(
        "parsers",
        title: "Parser tests"
    ) {
        prebuiltIPAddressRegressionSuite
        markdownStructuredContentSuite
        pklSyntaxSuite
        pklParserSuite
        pklCodingSuite
    }
}
