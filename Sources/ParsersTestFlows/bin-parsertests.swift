import TestFlows

@main
enum ParserTestCLI {
    static func main() async {
        await TestFlowCLI.run(
            suite: ParserFlowSuite.self
        )
    }
}
