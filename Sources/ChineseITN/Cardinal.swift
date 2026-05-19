// Cardinal.swift
// Convert Chinese cardinal numerals to Arabic digits.
// Ported from WeTextProcessing itn/chinese/rules/cardinal.py (Apache-2.0).
//
// Two entry points:
//   - `parse(_:)`: parse a single contiguous cardinal expression.
//                 Returns Arabic string OR nil if not a cardinal.
//   - `normalize(_:)`: scan a sentence and convert cardinal runs in
//                 place, preserving everything else.

import Foundation

enum Cardinal {

    // MARK: Single-expression parse

    /// Parse a Chinese cardinal expression standalone. Returns the
    /// Arabic representation OR nil.
    /// - Single digit chars stay as-is ("一" → "一").
    /// - Pure digit sequence ≥2 chars: digit-by-digit ("二零二六" → "2026").
    /// - Has unit chars: positional reading.
    /// - Coefficient with 千/百 before 万 keeps 万 suffix ("两千五百万" → "2500万").
    static func parse(_ s: String) -> String? {
        if s.isEmpty { return nil }
        if s.allSatisfy({ digitChars.contains($0) }) {
            if s.count == 1 { return String(s) }   // single char stays
            // WeText cardinal.py line ~92 recognizes specific
            // digit-sequence lengths as standalone cardinals:
            //   cardinal |= (digits**3 | digits**4 | digits**5
            //                | digits**11 | (digits**17 + idcard)
            //                | digits**18)
            // Lengths 11 / 17+1 / 18 are Chinese mobile phone and
            // ID-card-specific. When a sequence is longer (e.g. 15
            // chars), WeText's FST picks the cheapest split using
            // these length classes — typically (length-11) + 11
            // when the prefix length is also valid (3-5).
            if (14...16).contains(s.count) {
                let prefixLen = s.count - 11
                if (3...5).contains(prefixLen) {
                    let chars = Array(s)
                    let prefix = String(chars.prefix(prefixLen).map { digitMap[$0]! })
                    let suffix = String(chars.suffix(11).map { digitMap[$0]! })
                    return "\(prefix) \(suffix)"
                }
            }
            return String(s.map { digitMap[$0]! })  // digit-by-digit
        }
        if let kept = parseKeepingTenThousandSuffix(s) {
            return kept
        }
        return positionalValue(s).map(String.init)
    }

    /// Like `parse` but always returns an integer value. Single digit
    /// chars convert too (一 → 1). Used by Time / Date / Money / Fraction
    /// where we need a numeric value regardless of source form.
    static func parseToInt(_ s: String) -> Int? {
        if s.isEmpty { return nil }
        if s.allSatisfy({ digitChars.contains($0) }) {
            // Try digit-by-digit reading
            let arabic = String(s.map { digitMap[$0]! })
            return Int(arabic)
        }
        return positionalValue(s)
    }

    /// When the input ends with 万 and the prefix uses 百/千, keep
    /// 万 as a readable suffix: "两千五百万" → "2500万".
    private static func parseKeepingTenThousandSuffix(_ s: String) -> String? {
        guard let last = s.last, last == "万" || last == "萬" else {
            return nil
        }
        let prefix = String(s.dropLast())
        guard prefix.contains("百") || prefix.contains("千") else { return nil }
        guard let prefixVal = positionalValue(prefix) else { return nil }
        return "\(prefixVal)万"
    }

    /// Positional state-machine reading. See README rule notes for
    /// the trailing-digit "X位置位" rule (一百一→110, 一百零一→101).
    static func positionalValue(_ s: String) -> Int? {
        var total = 0
        var section = 0
        var pending = 0
        var hasPending = false
        var lastUnit = 1
        var sawZero = false

        for ch in s {
            switch ch {
            case "零", "〇", "洞":
                pending = 0
                hasPending = false
                sawZero = true
            case "十":
                let coef = hasPending ? pending : 1
                section += coef * 10
                pending = 0; hasPending = false
                lastUnit = 10; sawZero = false
            case "百":
                guard hasPending else { return nil }
                section += pending * 100
                pending = 0; hasPending = false
                lastUnit = 100; sawZero = false
            case "千":
                guard hasPending else { return nil }
                section += pending * 1000
                pending = 0; hasPending = false
                lastUnit = 1000; sawZero = false
            case "万", "萬":
                let cur = section + (hasPending ? pending : 0)
                if cur == 0 { return nil }
                total = (total + cur) * 10000
                section = 0; pending = 0; hasPending = false
                lastUnit = 10000; sawZero = false
            case "亿", "億":
                let cur = section + (hasPending ? pending : 0)
                if cur == 0 { return nil }
                total = (total + cur) * 100_000_000
                section = 0; pending = 0; hasPending = false
                lastUnit = 100_000_000; sawZero = false
            default:
                if let arabic = digitMap[ch], let d = Int(String(arabic)) {
                    pending = d; hasPending = true
                } else { return nil }
            }
        }
        if hasPending {
            let position = sawZero ? 1 : max(1, lastUnit / 10)
            section += pending * position
        }
        return total + section
    }

    // MARK: In-sentence scanner

    /// Regex matching any run of cardinal characters (digits + units).
    private static let _cardinalRunRE = try! NSRegularExpression(
        pattern: "[\(cnCardinalClass)]+"
    )

    /// Scan a sentence and convert cardinal runs to Arabic.
    ///
    /// Rules per run:
    /// - Single digit char: keep Chinese.
    /// - Pure digit sequence ≥2 chars: digit-by-digit.
    /// - Run contains unit chars (十/百/千/万/亿): positional parse.
    /// - If parse fails, keep original.
    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _cardinalRunRE) { match, ns in
            let run = ns.substring(with: match.range)
            // Single DIGIT char (not unit char): keep Chinese.
            // "一" → "一" but "十" → "10".
            if run.count == 1, let ch = run.first, digitChars.contains(ch) {
                return run
            }
            if let result = parse(run) {
                return result
            }
            return run
        }
    }
}
