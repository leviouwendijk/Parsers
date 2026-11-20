import Errors

// Input that does not parse: each prebuilt parser's failures keep their
// own text and gain a code (`parsers.email.missing_at`) and a disposition.

extension Prebuilt.HTMLCheckboxParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.html_checkbox"

    public var errorCode: String {
        switch self {
        case .invalidValue: return "invalid_value"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.IPAddressParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.ip_address"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .invalidIPAddress: return "invalid_ip_address"
        case .unspecifiedIPAddress: return "unspecified_ip_address"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.NonEmptyTextParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.non_empty_text"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .tooShort: return "too_short"
        case .tooLong: return "too_long"
        case .invalidCharacter: return "invalid_character"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.ForwardedClientIPParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.forwarded_client_ip"

    public var errorCode: String {
        switch self {
        case .missing: return "missing"
        case .emptyChain: return "empty_chain"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.DateSpecificationParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.date_specification"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .inferDisallowed: return "infer_disallowed"
        case .invalidInferSyntax: return "invalid_infer_syntax"
        case .invalidLiteral: return "invalid_literal"
        case .invalidUnixEpoch: return "invalid_unix_epoch"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.PostalCodeNLParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.postal_code_nl"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .invalidFormat: return "invalid_format"
        case .invalidCharacter: return "invalid_character"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.HouseNumberParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.house_number"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .invalidFormat: return "invalid_format"
        case .invalidCharacter: return "invalid_character"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.PhysicalAddressError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.physical_address"

    public var errorCode: String {
        switch self {
        case .incomplete: return "incomplete"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.EmailParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.email"

    public var errorCode: String {
        switch self {
        case .emptyLocalPart: return "empty_local_part"
        case .emptyDomain: return "empty_domain"
        case .missingAt: return "missing_at"
        case .invalidCharacter: return "invalid_character"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.HumanNameComponentsParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.human_name"

    public var errorCode: String {
        switch self {
        case .tooFewParts: return "too_few_parts"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.BoundedIntegerParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.bounded_integer"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .invalidCharacter: return "invalid_character"
        case .overflow: return "overflow"
        case .outOfRange: return "out_of_range"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.CORSOriginPatternError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.cors_origin_pattern"

    public var errorCode: String {
        switch self {
        case .invalidHost: return "invalid_host"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.RawInputValueError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.raw_input"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.DomainNameParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.domain_name"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .invalidCharacter: return "invalid_character"
        case .invalidLabel: return "invalid_label"
        case .labelTooLong: return "label_too_long"
        case .nameTooLong: return "name_too_long"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.OriginParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.origin"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .invalidScheme: return "invalid_scheme"
        case .missingSchemeSeparator: return "missing_scheme_separator"
        case .emptyHost: return "empty_host"
        case .invalidCharacter: return "invalid_character"
        case .invalidPort: return "invalid_port"
        case .invalidIPv6Literal: return "invalid_ipv6_literal"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.HoneypotParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.honeypot"

    public var errorCode: String {
        switch self {
        case .mustBeEmpty: return "must_be_empty"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.PhoneParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.phone"

    public var errorCode: String {
        switch self {
        case .empty: return "empty"
        case .misplacedPlus: return "misplaced_plus"
        case .invalidCharacter: return "invalid_character"
        case .tooShort: return "too_short"
        case .tooLong: return "too_long"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension Prebuilt.Content.DateBlockParserError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "parsers.date_block"

    public var errorCode: String {
        switch self {
        case .duplicateField: return "duplicate_field"
        case .unexpectedField: return "unexpected_field"
        case .expectedNumericValue: return "expected_numeric_value"
        case .expectedIntegerValue: return "expected_integer_value"
        case .integerOutOfRange: return "integer_out_of_range"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}
