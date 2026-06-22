import TestFlows

enum ParserFlowSuite: TestFlowRegistry {
    static let title = "Parser Test Flows"

    static let flows: [TestFlow] = [
        prebuiltIPAddressRegressionFlow
    ]
}
