// DateNormalize.swift
// Year / Month / Day normalization. Output style follows
// fun_text_processing's verbalizer:
//
//   二零二六年五月四号 → 2026年05月04日
//   五月四号           → 05月04日
//   三月二十一日       → 03月21日
//   二零二六年         → 2026年
//
// Year: 2-4 digit chars + 年 → keep 年 (year is digit-by-digit)
// Month: 1-12 + 月 → zero-padded MM
// Day: 1-31 + (日|号) → zero-padded DD, normalize 号 → 日

import Foundation

enum DateNormalize {

    static func normalize(_ text: String) -> String {
        var t = text
        t = normalizeYear(t)
        t = normalizeMonth(t)
        t = normalizeDay(t)
        return t
    }

    /// Match 2-to-4 char digit-only sequence + 年.
    /// Combines WeText's broader matching (handles "公元一六八年" 3-char
    /// and "零八年" 2-char) with fun_text_processing's "X年" format
    /// (year + 年 kept, no separator change).
    private static let _yearRE = try! NSRegularExpression(
        pattern: "(?<![\(cnDigitClass)])([\(cnDigitClass)]{2,4})年"
    )
    private static func normalizeYear(_ text: String) -> String {
        regexReplace(text, regex: _yearRE) { match, ns in
            let cnPart = ns.substring(with: match.range(at: 1))
            let arabic = String(cnPart.compactMap { digitMap[$0] })
            return "\(arabic)年"
        }
    }

    private static let _monthRE = try! NSRegularExpression(
        pattern: "([\(cnCardinalClass)]+)月"
    )
    private static func normalizeMonth(_ text: String) -> String {
        regexReplace(text, regex: _monthRE) { match, ns in
            let cnPart = ns.substring(with: match.range(at: 1))
            guard let n = Cardinal.parseToInt(cnPart),
                  (1...12).contains(n) else {
                return ns.substring(with: match.range)
            }
            return String(format: "%02d月", n)
        }
    }

    private static let _dayRE = try! NSRegularExpression(
        pattern: "([\(cnCardinalClass)]+)(日|号|號)"
    )
    private static func normalizeDay(_ text: String) -> String {
        regexReplace(text, regex: _dayRE) { match, ns in
            let cnPart = ns.substring(with: match.range(at: 1))
            guard let n = Cardinal.parseToInt(cnPart),
                  (1...31).contains(n) else {
                return ns.substring(with: match.range)
            }
            return String(format: "%02d日", n)
        }
    }
}
