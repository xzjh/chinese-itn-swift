// DateNormalize.swift
// Year / Month / Day normalization, matching WeTextProcessing
// itn/chinese/rules/date.py output:
//
//   二零二六年五月四号    → 2026/05/04
//   二零零八年八月        → 2008/08
//   八月八日              → 08/08
//   二零二六年            → 2026年   (year-only standalone keeps 年)
//   公元一六八年          → 公元168年 (3-char year — WeText broader form)
//
// WeText date.py rules (lines 31-44):
//   yyyy = digit + (digit | zero)**3  (4-char year)
//   yyy  = digit + (digit | zero)**2  (3-char year, after 公元 etc.)
//   yy   = (digit | zero)**2          (2-char year)
//   year (followed by month): drop 年, replaced with "/" by verbalizer
//   year_only (standalone): keep 年
//   month / day verbalize as zero-padded "/"-separated
//
// Examples per WeText official test/data/date.txt:
//   二零零八年八月八日 → 2008/08/08
//   二零零八年        → 2008年
//   两千零五年八月五号 → 2005年08/05  (mixed style, WeText edge case)

import Foundation

enum DateNormalize {

    static func normalize(_ text: String) -> String {
        var t = text
        // Full Y/M/D first (so year doesn't consume in standalone form).
        t = normalizeYearMonthDay(t)
        t = normalizeYearMonth(t)
        t = normalizeMonthDay(t)
        t = normalizeYearOnly(t)
        return t
    }

    /// Year + Month + Day → YYYY/MM/DD form.
    private static let _ymdRE = try! NSRegularExpression(
        pattern: "([\(cnDigitClass)]{2,4})年([\(cnCardinalClass)]+)月([\(cnCardinalClass)]+)(?:日|号|號)"
    )
    private static func normalizeYearMonthDay(_ text: String) -> String {
        regexReplace(text, regex: _ymdRE) { match, ns in
            let y = ns.substring(with: match.range(at: 1))
            let m = ns.substring(with: match.range(at: 2))
            let d = ns.substring(with: match.range(at: 3))
            let yArabic = String(y.compactMap { digitMap[$0] })
            guard let mInt = Cardinal.parseToInt(m), (1...12).contains(mInt),
                  let dInt = Cardinal.parseToInt(d), (1...31).contains(dInt)
            else { return ns.substring(with: match.range) }
            return String(format: "%@/%02d/%02d", yArabic, mInt, dInt)
        }
    }

    /// Year + Month → YYYY/MM (no day).
    private static let _ymRE = try! NSRegularExpression(
        pattern: "([\(cnDigitClass)]{2,4})年([\(cnCardinalClass)]+)月(?![\(cnCardinalClass)])"
    )
    private static func normalizeYearMonth(_ text: String) -> String {
        regexReplace(text, regex: _ymRE) { match, ns in
            let y = ns.substring(with: match.range(at: 1))
            let m = ns.substring(with: match.range(at: 2))
            let yArabic = String(y.compactMap { digitMap[$0] })
            guard let mInt = Cardinal.parseToInt(m), (1...12).contains(mInt)
            else { return ns.substring(with: match.range) }
            return String(format: "%@/%02d", yArabic, mInt)
        }
    }

    /// Month + Day standalone → MM/DD.
    private static let _mdRE = try! NSRegularExpression(
        pattern: "(?<![\(cnCardinalClass)年])([\(cnCardinalClass)]+)月([\(cnCardinalClass)]+)(?:日|号|號)"
    )
    private static func normalizeMonthDay(_ text: String) -> String {
        regexReplace(text, regex: _mdRE) { match, ns in
            let m = ns.substring(with: match.range(at: 1))
            let d = ns.substring(with: match.range(at: 2))
            guard let mInt = Cardinal.parseToInt(m), (1...12).contains(mInt),
                  let dInt = Cardinal.parseToInt(d), (1...31).contains(dInt)
            else { return ns.substring(with: match.range) }
            return String(format: "%02d/%02d", mInt, dInt)
        }
    }

    /// Year standalone (NOT followed by month) → YYYY年.
    /// Matches 2-4 digit chars before 年.
    private static let _yearRE = try! NSRegularExpression(
        pattern: "(?<![\(cnDigitClass)])([\(cnDigitClass)]{2,4})年(?![\(cnCardinalClass)0-9])"
    )
    private static func normalizeYearOnly(_ text: String) -> String {
        regexReplace(text, regex: _yearRE) { match, ns in
            let y = ns.substring(with: match.range(at: 1))
            let yArabic = String(y.compactMap { digitMap[$0] })
            return "\(yArabic)年"
        }
    }
}
