// Fraction.swift
// Fraction normalization. WeText behavior:
//
//   百分之X → X%
//   X分之Y → Y/X    (when X is parseable as small integer)
//   千分之X / 万分之X → unchanged (WeText doesn't convert; we match)

import Foundation

enum Fraction {

    /// 百分之X — must run BEFORE generic X分之Y since 百 alone is a unit.
    private static let _percentRE = try! NSRegularExpression(
        pattern: "百分之([\(cnCardinalClass)]+)"
    )

    /// Generic X分之Y where X is a small cardinal (digit 1-9 only;
    /// 百/千/万 prefixed forms NOT handled here per WeText).
    private static let _fractionRE = try! NSRegularExpression(
        pattern: "([\(cnDigitClass)])分之([\(cnCardinalClass)]+)"
    )

    static func normalize(_ text: String) -> String {
        var t = text
        // Percent first
        t = regexReplace(t, regex: _percentRE) { match, ns in
            let valCN = ns.substring(with: match.range(at: 1))
            guard let n = Cardinal.parseToInt(valCN) else {
                return ns.substring(with: match.range)
            }
            return "\(n)%"
        }
        // Fraction X分之Y
        t = regexReplace(t, regex: _fractionRE) { match, ns in
            let denomCN = ns.substring(with: match.range(at: 1))
            let numerCN = ns.substring(with: match.range(at: 2))
            guard let denom = Cardinal.parseToInt(denomCN),
                  let numer = Cardinal.parseToInt(numerCN) else {
                return ns.substring(with: match.range)
            }
            return "\(numer)/\(denom)"
        }
        return t
    }
}
