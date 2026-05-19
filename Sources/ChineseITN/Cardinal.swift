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
    /// - Coefficient with 千/百 before 万 keeps 万 suffix when
    ///   `enableMillion=false` ("两千五百万" → "2500万"). When
    ///   `enableMillion=true`, fully arabize ("两千五百万" → "25000000").
    static func parse(_ s: String, enableMillion: Bool = false) -> String? {
        if s.isEmpty { return nil }
        if let ipForm = parseDottedDigits(s) {
            return ipForm
        }
        if s.allSatisfy({ digitChars.contains($0) }) {
            if s.count == 1 { return String(s) }
            let allowedLengths: Set<Int> = [3, 4, 5, 11, 18]
            if allowedLengths.contains(s.count) {
                return String(s.map { digitMap[$0]! })
            }
            return nil
        }
        // 亿 always splits as text (WeText FST always uses
        // `accep("亿")`); 万 splitting is controlled by enableMillion.
        if let kept = parseKeepingTenThousandSuffix(s, enableMillion: enableMillion) {
            return kept
        }
        if !enableMillion, let kept = parseMidWanSeparator(s) {
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
            // WeText pure-digit cardinal is restricted to specific
            // lengths (1, 3, 4, 5, 11, 18). Other lengths shouldn't
            // be read as digit-by-digit cardinals (e.g. "七八" isn't
            // 78 — it's a tilde range pair). Single digit always OK
            // for caller (some callers use this for direct char read).
            let allowedLengths: Set<Int> = [1, 3, 4, 5, 11, 18]
            if !allowedLengths.contains(s.count) {
                return nil
            }
            let arabic = String(s.map { digitMap[$0]! })
            return Int(arabic)
        }
        return positionalValue(s)
    }

    /// IP-like dotted form: digits.plus + (点 + digits.plus).plus.
    /// Returns "127.0.0.1" for "幺二七点零点零点幺". Requires at least
    /// two 点 separators (more than a single decimal point).
    private static func parseDottedDigits(_ s: String) -> String? {
        let segments = s.split(separator: "点", omittingEmptySubsequences: false)
        guard segments.count >= 3,
              segments.allSatisfy({ seg in
                  !seg.isEmpty && seg.allSatisfy { digitChars.contains($0) }
              }) else { return nil }
        let arabicSegs: [String] = segments.map { seg in
            String(seg.map { digitMap[$0]! })
        }
        return arabicSegs.joined(separator: ".")
    }

    /// Big-number reader: split at 亿 and 万 boundaries, keep each
    /// magnitude marker as text in the output.
    /// WeText cardinal.py / measure.py convention:
    ///   "三亿五千万"        → "3亿5000万"
    ///   "一千万一千一百一十一" → "1000万1111"
    ///   "一亿两千三百"       → "1亿2300"
    ///   "一亿七万两千三百"    → "1亿72300" (亿-trailing has its own 万 segment merged)
    /// "两千五百万" alone (no 亿, ends in 万) → "2500万".
    /// "三亿" → "3亿"; standalone "一亿" same (WeText official-config behavior).
    private static func parseKeepingTenThousandSuffix(_ s: String,
                                                      enableMillion: Bool) -> String? {
        // 亿-split path: always keep 亿 as text marker.
        // WeText cardinal.py always uses `accep("亿")` regardless of
        // enable_million.
        if let yiIdx = s.firstIndex(where: { $0 == "亿" || $0 == "億" }) {
            let yiPrefix = String(s[..<yiIdx])
            let afterYi = String(s[s.index(after: yiIdx)...])
            guard let yiVal = positionalValue(yiPrefix), yiVal > 0 else { return nil }
            // Trailing empty: bare X亿
            if afterYi.isEmpty {
                return "\(yiVal)亿"
            }
            // Strip leading 零 (一亿零两千三百 form)
            var rest = afterYi
            if let firstChar = rest.first, firstChar == "零" || firstChar == "〇" {
                rest = String(rest.dropFirst())
            }
            // Trailing positional: may include 万 segment
            if rest.contains("万") || rest.contains("萬") {
                guard let tail = parseKeepingTenThousandSuffix(rest, enableMillion: enableMillion)
                        ?? (!enableMillion ? parseMidWanSeparator(rest) : nil) else {
                    guard let restVal = positionalValue(rest) else { return nil }
                    return "\(yiVal)亿\(restVal)"
                }
                return "\(yiVal)亿\(tail)"
            }
            guard let restVal = positionalValue(rest) else { return nil }
            return "\(yiVal)亿\(restVal)"
        }
        // 万-trailing path — only active when !enableMillion.
        if enableMillion { return nil }
        guard let last = s.last, last == "万" || last == "萬" else { return nil }
        let prefix = String(s.dropLast())
        guard prefix.contains("百") || prefix.contains("千") else { return nil }
        guard let prefixVal = positionalValue(prefix) else { return nil }
        return "\(prefixVal)万"
    }

    /// 万-in-middle: "一千万一千一百一十一" → "1000万1111".
    /// Upper part must be 百/千-magnitude reading.
    private static func parseMidWanSeparator(_ s: String) -> String? {
        guard let wanIdx = s.firstIndex(where: { $0 == "万" || $0 == "萬" }),
              wanIdx != s.index(before: s.endIndex) else { return nil }
        let upper = String(s[..<wanIdx])
        var lower = String(s[s.index(after: wanIdx)...])
        if let f = lower.first, f == "零" || f == "〇" { lower.removeFirst() }
        guard !lower.isEmpty,
              upper.contains("百") || upper.contains("千"),
              let upperVal = positionalValue(upper),
              let lowerVal = positionalValue(lower) else { return nil }
        return "\(upperVal)万\(lowerVal)"
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
                    // Two consecutive digits without intervening unit
                    // is invalid: "三百九十九三" — the trailing 三 isn't
                    // part of the same positional read. Returning nil
                    // here lets the normalizeRun caller split the run
                    // at a shorter prefix that does parse.
                    if hasPending { return nil }
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

    // MARK: Module-level normalize (delegates to lattice)

    /// WeText sign.tsv — leading polarity marker. Used by the
    /// tag() function in Taggers.swift.
    static let signMap: [String: String] = [
        "正负": "±",
        "负的": "-",
        "正": "+",
        "负": "-",
    ]

    /// Normalize using only this module's tagger + Char fallback.
    /// Useful for testing the module in isolation; the full pipeline
    /// is `ChineseITN.normalize`.
    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = Cardinal.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}

