import DSL

public enum MarkdownStructuredContentParser {
    /// Parse a presentation-oriented Markdown subset into StructuredContent.
    ///
    /// The returned value is a derived semantic projection. Callers that need
    /// exact Markdown for copying, persistence, or model history should retain
    /// the original source separately.
    public static func parse(
        _ source: String
    ) -> StructuredContent {
        var parser = MarkdownBlockParser(
            source: source
        )

        return parser.parse()
    }
}
