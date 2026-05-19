// Time.swift
// Time expression normalization.
// Ported from WeTextProcessing itn/chinese/rules/time.py.
//
// Only fires when minute info (X分 or 半) is present. Just an hour
// (X点 without minute) is left to Cardinal for digit conversion.
//
// Examples:
//   "下午三点四十五分" → "3:45p.m."
//   "下午三点半"      → "3:30p.m."
//   "三点半"          → "3:30"
//   "凌晨三点半"      → "凌晨3:30"      (凌晨 not in noon map; kept)
//   "下午三点"        → "下午三点"      (no minute; falls through)

import Foundation

enum TimeNormalize {

    /// (noon_prefix)? + cardinal_hour + 点 + (半 | cardinal_minute + 分)
    private static let _re = try! NSRegularExpression(
        pattern: "(上午|早上|早晨|下午|晚上|傍晚|凌晨|中午)?([\(cnCardinalClass)]+)点(?:(半)|([\(cnCardinalClass)]+)分)?"
    )

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let r = match.range
            let original = ns.substring(with: r)

            let noonPart = match.range(at: 1).location != NSNotFound
                ? ns.substring(with: match.range(at: 1)) : ""
            let hourCN = ns.substring(with: match.range(at: 2))
            let isBan = match.range(at: 3).location != NSNotFound
            let hasMinute = match.range(at: 4).location != NSNotFound
            let minuteCN = hasMinute ? ns.substring(with: match.range(at: 4)) : ""

            // Pass through if no minute info — let Cardinal handle bare hour.
            guard isBan || hasMinute else { return original }

            guard let hour = Cardinal.parseToInt(hourCN),
                  (0...24).contains(hour) else {
                return original
            }

            let minute: Int
            if isBan {
                minute = 30
            } else {
                guard let m = Cardinal.parseToInt(minuteCN),
                      (0...59).contains(m) else {
                    return original
                }
                minute = m
            }

            let mmFormatted = String(format: "%02d", minute)
            let timeStr = "\(hour):\(mmFormatted)"

            // Noon prefix handling
            if let noon = noonMap[noonPart] {
                return "\(timeStr)\(noon)"
            }
            return "\(noonPart)\(timeStr)"
        }
    }
}
