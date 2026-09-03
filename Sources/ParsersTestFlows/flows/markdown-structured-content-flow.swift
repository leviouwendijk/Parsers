import DSL
import ParsersStructuredContent
import TestFlows

extension ParserFlowSuite {
    static let markdownStructuredContentFlow = TestFlow(
        "structured-content.markdown",
        title: "Markdown parses into StructuredContent",
        tags: [
            "parsers",
            "markdown",
            "structured-content",
        ]
    ) {
        Step("common model markdown maps to semantic content") {
            let source = """
                # Runtime

                Use **typed** `ToolPlan` values.

                - observe
                - mutate
                    - approve

                > Keep *raw* markdown.

                ```swift
                let value = 1
                ```
                """

            let parsed =
                MarkdownStructuredContentParser.parse(
                    source
                )

            let expected: StructuredContent =
                .collection([
                    .group(
                        role: "markdown.heading.1",
                        title: [
                            .text("Runtime"),
                        ],
                        content:
                            .collection([
                                .paragraph([
                                    .text("Use "),
                                    .strong([
                                        .text("typed"),
                                    ]),
                                    .text(" "),
                                    .code("ToolPlan"),
                                    .text(" values."),
                                ]),
                                .list(
                                    style: .unordered,
                                    items: [
                                        .paragraph([
                                            .text("observe"),
                                        ]),
                                        .collection([
                                            .paragraph([
                                                .text("mutate"),
                                            ]),
                                            .list(
                                                style: .unordered,
                                                items: [
                                                    .paragraph([
                                                        .text("approve"),
                                                    ]),
                                                ]
                                            ),
                                        ]),
                                    ]
                                ),
                                .quote(
                                    .collection([
                                        .paragraph([
                                            .text("Keep "),
                                            .emphasis([
                                                .text("raw"),
                                            ]),
                                            .text(" markdown."),
                                        ]),
                                    ])
                                ),
                                .code(
                                    language: "swift",
                                    source: "let value = 1"
                                ),
                            ])
                    ),
                ])

            try Expect.equal(
                parsed,
                expected,
                "markdown.structured-content.common"
            )
        }

        Step("headings form nested semantic sections") {
            let parsed =
                MarkdownStructuredContentParser.parse(
                    """
                    # Parent

                    Intro.

                    ## Child

                    Body.

                    ### Grandchild

                    More.
                    """
                )

            let expected: StructuredContent =
                .collection([
                    .group(
                        role: "markdown.heading.1",
                        title: [
                            .text("Parent"),
                        ],
                        content:
                            .collection([
                                .paragraph([
                                    .text("Intro."),
                                ]),
                                .group(
                                    role: "markdown.heading.2",
                                    title: [
                                        .text("Child"),
                                    ],
                                    content:
                                        .collection([
                                            .paragraph([
                                                .text("Body."),
                                            ]),
                                            .group(
                                                role: "markdown.heading.3",
                                                title: [
                                                    .text("Grandchild"),
                                                ],
                                                content:
                                                    .collection([
                                                        .paragraph([
                                                            .text("More."),
                                                        ]),
                                                    ])
                                            ),
                                        ])
                                ),
                            ])
                    ),
                ])

            try Expect.equal(
                parsed,
                expected,
                "markdown.structured-content.headings"
            )
        }

        Step("unsupported or incomplete syntax remains text") {
            let parsed =
                MarkdownStructuredContentParser.parse(
                    "Keep *unfinished and [links](raw) unchanged."
                )

            let expected: StructuredContent =
                .collection([
                    .paragraph([
                        .text(
                            "Keep *unfinished and [links](raw) unchanged."
                        ),
                    ]),
                ])

            try Expect.equal(
                parsed,
                expected,
                "markdown.structured-content.fallback"
            )
        }
    }
}
