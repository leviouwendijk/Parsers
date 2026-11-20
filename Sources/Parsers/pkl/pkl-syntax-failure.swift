import Errors
import Parsing

extension Pkl.SyntaxFailure:
    SemanticError,
    ErrorDispositionProviding
{
    public var errorIdentity: ErrorIdentity {
        .init(namespace: "parsers.pkl", code: "syntax")
    }

    public var errorPresentation: ErrorPresentation {
        .init(
            message: "Pkl syntax error.",
            // The parser's text may quote the source.
            reason: diagnostic.message,
            reasonSensitivity: .potentially_sensitive
        )
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        diagnostic.errorFields
    }

    public var errorDisposition: ErrorDisposition? {
        .invalid_input
    }
}
