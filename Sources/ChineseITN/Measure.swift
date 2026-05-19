// Measure.swift
// Cardinal / decimal + unit binding. Converts Chinese unit suffix
// to its scientific abbreviation (米 → m, 千克 → kg, etc.) and
// arabizes the number.
// Ported from WeTextProcessing itn/chinese/rules/measure.py +
// data/measure/units_en.tsv (Apache-2.0, 85 zh→en unit mappings).
//
// Examples:
//   一千克       → 1kg
//   重达二十五千克 → 重达25kg
//   三百二十四点七五克 → 324.75g
//   最高气温三十八摄氏度 → 最高气温38°C
//   实际面积一百二十平方米 → 实际面积120m²

import Foundation

enum Measure {

    /// WeText data/measure/units_en.tsv — Chinese unit name to
    /// scientific abbreviation. Sorted by descending length so a
    /// longest-match-first regex works.
    static let unitMap: [String: String] = [
        "万亿焦耳": "tj",
        "千米每小时": "km/h",
        "千米一小时": "km/h",
        "公里每小时": "km/h",
        "公里一小时": "km/h",
        "英里每小时": "mph",
        "英里一小时": "mph",
        "千比特每秒": "kbps",
        "千比特一秒": "kbps",
        "兆比特每秒": "mbps",
        "兆比特一秒": "mbps",
        "平方厘米": "cm²",
        "立方厘米": "cm³",
        "平方千米": "km²",
        "立方分米": "dm³",
        "平方英尺": "sq ft",
        "平方英里": "sq mi",
        "平方毫米": "mm²",
        "原子质量": "amu",
        "吉帕斯卡": "gpa",
        "吉瓦时": "gwh",
        "千瓦时": "kwh",
        "兆赫兹": "mhz",
        "吉赫兹": "ghz",
        "千赫兹": "khz",
        "千克力": "kgf",
        "帕斯卡": "pa",
        "平方米": "m²",
        "立方米": "m³",
        "摄氏度": "°C",
        "华氏度": "°F",
        "分钟": "min",
        "千卡": "kcal",
        "千克": "kg",
        "公斤": "kg",
        "千米": "km",
        "公里": "km",
        "千瓦": "kw",
        "千伏": "kv",
        "千帕": "kpa",
        "毫升": "ml",
        "毫米": "mm",
        "毫秒": "ms",
        "毫伏": "mv",
        "毫瓦": "mw",
        "毫克": "mg",
        "微克": "μg",
        "微米": "μm",
        "微秒": "μs",
        "美担": "cwt",
        "戈瑞": "gy",
        "公顷": "ha",
        "英尺": "ft",
        "英里": "mi",
        "纳克": "ng",
        "纳米": "nm",
        "纳秒": "ns",
        "盎司": "oz",
        "皮克": "pg",
        "皮秒": "ps",
        "弧度": "rad",
        "摩尔": "mol",
        "赫兹": "hz",
        "兆帕": "mpa",
        "字节": "b",
        "吉字节": "gb",
        "太字节": "tb",
        "系沃特": "sv",
        "伏特": "v",
        "转每分": "rpm",
        "欧米茄": "ω",
        "分贝": "db",
        "吉瓦": "gw",
        "分米": "dm",
        "厘米": "cm",
        "巴": "bar",
        "克": "g",
        "米": "m",
        "秒": "s",
        "磅": "lbs",
        "码": "yd",
        "度": "°",
        "小时": "h",
    ]

    /// Match decimal-or-cardinal expression + unit.
    private static let _re: NSRegularExpression = {
        // Longest unit first to avoid 米 matching before 千米.
        let unitsSorted = unitMap.keys.sorted { $0.count > $1.count }
        let unitAlt = unitsSorted.joined(separator: "|")
        // Number: cardinal expression OR decimal "X点Y"
        let numCardinal = "[\(cnCardinalClass)]+"
        let numDecimal = "[\(cnCardinalClass)]+点[\(cnDigitClass)]+"
        return try! NSRegularExpression(
            pattern: "(\(numDecimal)|\(numCardinal))(\(unitAlt))"
        )
    }()

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let numStr = ns.substring(with: match.range(at: 1))
            let unitCN = ns.substring(with: match.range(at: 2))
            guard let unitEN = unitMap[unitCN] else {
                return ns.substring(with: match.range)
            }
            // Decimal form first
            if let dotIdx = numStr.firstIndex(where: { $0 == "点" || $0 == "點" }) {
                let intPart = String(numStr[..<dotIdx])
                let fracPart = String(numStr[numStr.index(after: dotIdx)...])
                guard let intVal = Cardinal.parseToInt(intPart) else {
                    return ns.substring(with: match.range)
                }
                let fracDigits = fracPart.compactMap { digitMap[$0] }
                guard fracDigits.count == fracPart.count else {
                    return ns.substring(with: match.range)
                }
                return "\(intVal).\(String(fracDigits))\(unitEN)"
            }
            // Cardinal form
            guard let n = Cardinal.parse(numStr) else {
                return ns.substring(with: match.range)
            }
            return "\(n)\(unitEN)"
        }
    }
}
