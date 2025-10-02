import Foundation
import AppKit

public enum AttributedStringRenderingError: Error, LocalizedError {
    case failedToConstructDataObject
    case failedToRender
}

public struct AttributedStringOptionHelper {
    public init() {}

    public static func justifiedParagraph() -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.alignment = .justified
        // para.lineSpacing = 4.0    
        return [.paragraphStyle: para]
    }

    public static func merge(arrays: [[NSAttributedString.Key: Any]]) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [:]
        for attrs in arrays {
            for (key, value) in attrs {
                result[key] = value
            }
        }
        return result
    }
}

public struct AttributedStringRenderer {
    /// Output format: .html, .rtf, .docx, etc.
    public var documentType: NSAttributedString.DocumentType
    public var characterEncoding: String.Encoding
    public var defaultAttributes: [NSAttributedString.Key: Any]?
    public var baseURL: URL?
    public var css: String?
    public var paperSize: NSSize?
    public var pageMargins: NSEdgeInsets?
    public var headerString: String?
    public var footerString: String?
    public var hyphenationFactor: Float?

    public init(
        documentType: NSAttributedString.DocumentType = .html,
        characterEncoding: String.Encoding = .utf8,
        defaultAttributes: [NSAttributedString.Key: Any]? = nil,
        baseURL: URL? = nil,
        css: String? = nil,
        paperSize: NSSize? = nil,
        pageMargins: NSEdgeInsets? = nil,
        headerString: String? = nil,
        footerString: String? = nil,
        hyphenationFactor: Float? = nil
    ) {
        self.documentType = documentType
        self.characterEncoding = characterEncoding
        self.defaultAttributes = defaultAttributes
        self.baseURL = baseURL
        self.css = css
        self.paperSize = paperSize
        self.pageMargins = pageMargins
        self.headerString = headerString
        self.footerString = footerString
        self.hyphenationFactor = hyphenationFactor
    }

    private static let kBaseURLKey = NSAttributedString.DocumentAttributeKey(rawValue: "NSBaseURLDocumentAttribute")
    private static let kPaperSizeKey = NSAttributedString.DocumentAttributeKey(rawValue: "NSPaperSizeDocumentAttribute")
    private static let kPageMarginsKey = NSAttributedString.DocumentAttributeKey(rawValue: "NSPageMarginsDocumentAttribute")
    private static let kHeaderKey = NSAttributedString.DocumentAttributeKey(rawValue: "NSHeaderDocumentAttribute")
    private static let kFooterKey = NSAttributedString.DocumentAttributeKey(rawValue: "NSFooterDocumentAttribute")
    private static let kHyphenationKey = NSAttributedString.DocumentAttributeKey(rawValue: "NSHyphenationFactorDocumentAttribute")

    public func renderData(from attributedString: NSAttributedString) throws -> Data {
        var attrs: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: documentType,
            .characterEncoding: characterEncoding.rawValue
        ]

        if let def = defaultAttributes {
            attrs[.defaultAttributes] = def
        }
        if let url = baseURL {
            attrs[Self.kBaseURLKey] = url
        }
        if let size = paperSize {
            attrs[Self.kPaperSizeKey] = size
        }
        if let margins = pageMargins {
            attrs[Self.kPageMarginsKey] = NSValue(edgeInsets: margins)
        }
        if let header = headerString {
            attrs[Self.kHeaderKey] = header
        }
        if let footer = footerString {
            attrs[Self.kFooterKey] = footer
        }
        if let hyph = hyphenationFactor {
            attrs[Self.kHyphenationKey] = hyph
        }

        let workString: NSAttributedString
        if documentType == .html, let css = css {
            let style = "<style>\(css)</style>\n"
            let mutable = NSMutableAttributedString(string: style)
            mutable.append(attributedString)
            workString = mutable
        } else {
            workString = attributedString
        }

        do {
            return try workString.data(
                from: NSRange(location: 0, length: workString.length),
                documentAttributes: attrs
            )
        } catch {
            throw AttributedStringRenderingError.failedToConstructDataObject
        }
    }

    public func render(from attributedString: NSAttributedString) throws -> String {
        let data = try renderData(from: attributedString)
        if let string = String(data: data, encoding: characterEncoding) {
            return string
        } else {
            throw AttributedStringRenderingError.failedToRender
        }
    }
}
