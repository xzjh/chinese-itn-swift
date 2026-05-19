// LicensePlate.swift
// Chinese vehicle license plate normalization.
// Ported from WeTextProcessing itn/chinese/rules/license_plate.py +
// data/license_plate/province.tsv (Apache-2.0).
//
// Plate format: <province char> + <ALPHA> + 5 or 6 of (ALPHA | digit).
// Province chars come from data/license_plate/province.tsv (31 entries).
//
// Examples:
//   京A幺二三四五       → 京A12345
//   鄂a七l六二u        → 鄂a7l62u    (mixed case, mixed alpha+digit)
//   皖C九B三四E        → 皖C9B34E
//   京A零七ZX三F       → 京A07ZX3F

import Foundation

enum LicensePlate {

    /// Chinese provinces that prefix a license plate. From WeText
    /// data/license_plate/province.tsv (31 entries).
    private static let provinceChars: Set<Character> = [
        "京", "津", "沪", "渝", "冀", "豫", "云", "辽",
        "黑", "湘", "皖", "鲁", "新", "苏", "浙", "赣",
        "鄂", "桂", "甘", "晋", "蒙", "陕", "吉", "闽",
        "贵", "粤", "青", "藏", "川", "宁", "琼",
    ]

    /// Match: <province><ALPHA> + 5-or-6 (ALPHA | DIGIT-CN | digit).
    private static let _re: NSRegularExpression = {
        let provinces = String(provinceChars).map(String.init).joined(separator: "")
        let alpha = "A-Za-z"
        let cnDigit = cnDigitClass
        // body = [a-zA-Z|cn-digit|0-9]{5,6}
        return try! NSRegularExpression(
            pattern: "([\(provinces)])([\(alpha)])([\(alpha)\(cnDigit)0-9]{5,6})"
        )
    }()

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let prov = ns.substring(with: match.range(at: 1))
            let firstAlpha = ns.substring(with: match.range(at: 2))
            let body = ns.substring(with: match.range(at: 3))
            // Convert any Chinese-digit chars in body to ASCII digits.
            let converted = String(body.map { ch in
                digitMap[ch] ?? ch
            })
            return "\(prov)\(firstAlpha)\(converted)"
        }
    }
}
