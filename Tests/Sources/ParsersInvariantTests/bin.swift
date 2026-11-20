import Testing

private enum ParsersInvariantTestFailure: Swift.Error {
    case failed
}

@main
enum ParsersInvariantTestMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter()
        let result = await TestRunner.run(ParsersInvariantTestsSuite.suite, sink: reporter)
        print(await reporter.rendered())
        if result.isFailure {
            throw ParsersInvariantTestFailure.failed
        }
    }
}
