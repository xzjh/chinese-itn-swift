// Math.swift
// Math expression normalization.
// Ported from WeTextProcessing itn/chinese/rules/math.py +
// data/math/operator.tsv (Apache-2.0).
//
// WeText pattern (math.py:30):
//     tagger = number + (operator + number).plus
// Operator table (data/math/operator.tsv):
//     乘 → ×, 减 → -, 到 → ~, 加 → +, 比 → :, 等于 → =, 除 → ÷
//
// Examples:
//   一加二      → 1+2
//   负一加二    → -1+2
//   一加二加三  → 1+2+3
//   二等于一加一 → 2=1+1
//   二十一到一千零一 → 21~1001

import Foundation

enum MathNormalize {

    /// WeText operator.tsv mapping.
    private static let operatorMap: [String: String] = [
        "乘": "×",
        "减": "-",
        "到": "~",
        "加": "+",
        "比": ":",
        "等于": "=",
        "除": "÷",
    ]

    /// Match `(负的?)?number((operator)number)+`.
    /// 负/负的 prefix handled as part of the cardinal sign.
    private static let _re: NSRegularExpression = {
        let opAlternation = operatorMap.keys.sorted { $0.count > $1.count }.joined(separator: "|")
        let signPrefix = "(?:负的?)?"
        let num = "[\(cnCardinalClass)]+"
        return try! NSRegularExpression(
            pattern: "(\(signPrefix)\(num))((?:(?:\(opAlternation))\(signPrefix)\(num))+)"
        )
    }()

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let original = ns.substring(with: match.range)
            // Parse: first number, then alternating operator+number.
            // Convert each number via Cardinal.parseToInt; reassemble
            // with mapped operators.
            //
            // We do our own scan because Foundation regex doesn't
            // easily give us per-pair groups for variable repetition.
            return assembleMath(original) ?? original
        }
    }

    /// Convert a math expression like "负一加二乘三" to "-1+2×3".
    private static func assembleMath(_ s: String) -> String? {
        var out = ""
        var idx = s.startIndex
        let end = s.endIndex
        var first = true

        while idx < end {
            // Try to consume optional sign prefix
            var sign = ""
            if s[idx...].hasPrefix("负的") {
                sign = "-"
                idx = s.index(idx, offsetBy: 2)
            } else if s[idx...].hasPrefix("负") {
                sign = "-"
                idx = s.index(idx, offsetBy: 1)
            }

            // Consume cardinal chars
            let numStart = idx
            while idx < end, let ch = s[idx...].first, cnCardinalClass.contains(ch) {
                idx = s.index(after: idx)
            }
            let numStr = String(s[numStart..<idx])
            guard !numStr.isEmpty,
                  let n = Cardinal.parseToInt(numStr) else { return nil }

            if first {
                out += "\(sign)\(n)"
                first = false
            } else {
                out += "\(sign)\(n)"
            }

            // Consume operator
            if idx >= end { break }
            var consumed = false
            for opLen in [2, 1] {
                if idx < end {
                    let upper = s.index(idx, offsetBy: opLen, limitedBy: end) ?? end
                    let candidate = String(s[idx..<upper])
                    if let op = operatorMap[candidate] {
                        out += op
                        idx = upper
                        consumed = true
                        break
                    }
                }
            }
            if !consumed { break }
        }
        return out
    }
}
