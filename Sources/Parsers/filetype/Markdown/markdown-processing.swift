import Foundation
import AppKit

public let namedEntities: [String: String] = [
    "amp":"&","lt":"<","gt":">","quot":"\"","apos":"'",
    "nbsp":"\u{00A0}","ndash":"\u{2013}","mdash":"\u{2014}","hellip":"\u{2026}"
]

@inline(__always)
public func decodeHTMLEntities(_ s: String) -> String {
    var out = s as NSString

    // numeric hex: &#xHHHH;
    if let rx = try? NSRegularExpression(pattern: #"&#x([0-9A-Fa-f]+);"#) {
        let matches = rx.matches(in: out as String, range: NSRange(location: 0, length: out.length)).reversed()
        for m in matches {
            let hex = out.substring(with: m.range(at: 1))
            if let v = UInt32(hex, radix: 16), let scalar = UnicodeScalar(v) {
                out = out.replacingCharacters(in: m.range, with: String(Character(scalar))) as NSString
            }
        }
    }
    // numeric dec: &#DDDD;
    if let rx = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
        let matches = rx.matches(in: out as String, range: NSRange(location: 0, length: out.length)).reversed()
        for m in matches {
            let dec = out.substring(with: m.range(at: 1))
            if let v = UInt32(dec), let scalar = UnicodeScalar(v) {
                out = out.replacingCharacters(in: m.range, with: String(Character(scalar))) as NSString
            }
        }
    }
    // named: &word;
    if let rx = try? NSRegularExpression(pattern: #"&([A-Za-z]+);"#) {
        let matches = rx.matches(in: out as String, range: NSRange(location: 0, length: out.length)).reversed()
        for m in matches {
            let key = out.substring(with: m.range(at: 1))
            if let rep = namedEntities[key] {
                out = out.replacingCharacters(in: m.range, with: rep) as NSString
            }
        }
    }
    return out as String
}

@inline(__always)
public func unescapeMarkdownPunctuation(_ s: String) -> String {
    let pattern = ##"\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])"##
    guard let rx = try? NSRegularExpression(pattern: pattern) else { return s }
    let ns = s as NSString
    let matches = rx.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed()
    var out = ns
    for m in matches {
        let ch = ns.substring(with: m.range(at: 1))
        out = out.replacingCharacters(in: m.range, with: ch) as NSString
    }
    return out as String
}

@inline(__always)
public func normalizeInline(_ s: String) -> String {
    unescapeMarkdownPunctuation(decodeHTMLEntities(s))
}
