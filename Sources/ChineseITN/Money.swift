// Money.swift
// Money / currency normalization.
// Ported from WeTextProcessing itn/chinese/rules/money.py +
// data/money/symbol.tsv + data/money/code.tsv (Apache-2.0).
//
// WeText money tagger (money.py:34):
//   tagger = number + currency(code|symbol) + decimal?
//   verbalize = currency + value + decimal
//
// So "X<currency>" rearranges to "<symbol>X". Decimal form
// "X元Y角Z分" → "<symbol>X.YZ".
//
// Examples:
//   两百欧元        → €200
//   一千美元        → $1000
//   一点二五元      → ¥1.25
//   三千三百八十元五角八分 → ¥3380.58 (TODO: not yet implemented)

import Foundation

enum Money {

    /// WeText data/money/symbol.tsv — Chinese currency name to
    /// symbol prefix. Subset adopting the unambiguous, common entries.
    /// 元 included (per WeText official "价格是十三点五元" → "¥13.5").
    static let symbolPrefix: [String: String] = [
        "美元": "$",
        "英镑": "£",
        "欧元": "€",
        "泰铢": "฿",
        "朝鲜园": "₩",
        "韩元": "₩",
        "印度卢比": "₹",
        "越南东": "₫",
        "土耳其里拉": "₺",
        "卢布": "₽",
        "乌克兰格里夫纳": "₴",
        "蒙古图格里克": "₮",
        "老挝基普": "₭",
        "尼日利亚奈拉": "₦",
        "古巴比索": "₱",
        "菲律宾比索": "₱",
        "以色列谢克尔": "₪",
        "哥斯达黎加科隆": "₡",
        "柬埔寨瑞尔": "៛",
        "巴西雷亚尔": "R$",
        "牙买加元": "J$",
        "马来西亚令吉": "RM",
        "印尼盾": "Rp",
        "巴拿马巴尔博亚": "B/.",
        "瑞士法郎": "CHF",
        "捷克克朗": "Kč",
        "丹麦克朗": "kr",
        "波兰兹罗提": "zł",
        "匈牙利福林": "Ft",
        "罗马尼亚列伊": "lei",
        "克罗地亚库纳": "kn",
        "南非兰特": "R",
        "津巴布韦元": "Z$",
        "尼加拉瓜科尔多瓦": "C$",
        "元": "¥",      // last so longer matches like 欧元/美元 win
    ]

    /// WeText data/money/code.tsv — names that get rewritten to a
    /// 3-letter code instead of a single symbol.
    static let codePrefix: [String: String] = [
        "澳元": "A$",
        "加元": "CAD",
        "港元": "HK＄",
        "新台币": "TWD",
        "人民币": "CNY",
        "新加坡元": "SGD",
        "瑞典克朗": "SEK",
        "挪威克朗": "NOK",
        "日元": "JPY",
        "韩元": "KRW",
        "印尼盾": "IDR",
        "印度卢比": "INR",
        "墨西哥比索": "MXN",
        "马来西亚令吉": "MYR",
    ]

    /// Match `(cardinal or decimal)(currency suffix)` and rearrange.
    private static let _re: NSRegularExpression = {
        // Longest currency name first so 美元 beats 元.
        let allCurrencies = Array(symbolPrefix.keys) + Array(codePrefix.keys)
        let unique = Array(Set(allCurrencies))
        let sorted = unique.sorted { $0.count > $1.count }
        let alt = sorted.joined(separator: "|")
        let numCardinal = "[\(cnCardinalClass)]+"
        let numDecimal = "[\(cnCardinalClass)]+点[\(cnDigitClass)]+"
        return try! NSRegularExpression(
            pattern: "(\(numDecimal)|\(numCardinal))(\(alt))"
        )
    }()

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let numStr = ns.substring(with: match.range(at: 1))
            let currency = ns.substring(with: match.range(at: 2))
            // Pick the right prefix table — symbol wins if both apply.
            let prefix = symbolPrefix[currency] ?? codePrefix[currency]
            guard let pre = prefix else {
                return ns.substring(with: match.range)
            }
            // Decimal form
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
                return "\(pre)\(intVal).\(String(fracDigits))"
            }
            // Cardinal form: produce "PREFIX<int>" via Cardinal.parse
            guard let n = Cardinal.parse(numStr) else {
                return ns.substring(with: match.range)
            }
            return "\(pre)\(n)"
        }
    }
}
