// RegexHelpers.swift
// Shared NSRegularExpression scan-and-replace utility used by every
// normalizer module.

import Foundation

/// Apply `transform` to every regex match in `text`, substituting
/// the result back. Non-matching spans pass through untouched.
@inline(__always)
func regexReplace(_ text: String, regex: NSRegularExpression,
                  transform: (NSTextCheckingResult, NSString) -> String) -> String {
    let ns = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return text }

    var result = ""
    var cursor = 0
    for m in matches {
        let r = m.range
        if r.location < cursor { continue }  // skip overlapping
        result += ns.substring(with: NSRange(location: cursor, length: r.location - cursor))
        result += transform(m, ns)
        cursor = r.location + r.length
    }
    if cursor < ns.length {
        result += ns.substring(from: cursor)
    }
    return result
}

/// Character classes for Chinese digit-char sequences (used by
/// many regex patterns).
let cnDigitClass = "零一二三四五六七八九〇洞两幺壹贰叁肆伍陆柒捌玖兩貳叁參陸"
let cnCardinalClass = "零一二三四五六七八九十百千万亿〇洞两幺壹贰叁肆伍陆柒捌玖萬億兩貳"
