// Decimal.swift
// X点Y → X.Y conversion.

import Foundation

enum Decimal {

    /// Match a cardinal integer part + 点/點 + one or more digit chars.
    /// Both sides use the digit class — units (十/百/千) allowed on the
    /// integer side, single-char digits only on the fractional side.
    private static let _re = try! NSRegularExpression(
        pattern: "([\(cnCardinalClass)]+)([点點])([\(cnDigitClass)]+)"
    )

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let intStr = ns.substring(with: match.range(at: 1))
            let fracStr = ns.substring(with: match.range(at: 3))
            // Single-char integer + single-char fractional: keep as-is
            // (matches WeText's single-cardinal-char preservation rule).
            // But for decimals, even bare "三点二" should convert to 3.2,
            // matching WeText fixture "三点二三" → "3.23".
            // So we DO convert single-char integer here.

            // Integer part: parse as cardinal. For pure digit char
            // sequence (no units), digit-by-digit.
            let intVal: String
            if intStr.count == 1 {
                guard let d = digitMap[intStr.first!] else {
                    return ns.substring(with: match.range)
                }
                intVal = String(d)
            } else if let v = Cardinal.parse(intStr) {
                intVal = v
            } else {
                return ns.substring(with: match.range)
            }

            // Fractional part: digit-by-digit
            let fracDigits = fracStr.compactMap { digitMap[$0] }
            guard fracDigits.count == fracStr.count else {
                return ns.substring(with: match.range)
            }
            return "\(intVal).\(String(fracDigits))"
        }
    }
}
