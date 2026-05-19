// Money.swift
// Money / currency normalization.
// Ported from WeTextProcessing itn/chinese/rules/money.py +
// data/money/symbol.tsv + data/money/code.tsv (Apache-2.0).
//
// Recognition logic lives in Taggers.swift (`Money.tag`).
//
// Examples:
//   两百欧元         → €200
//   一千美元         → USD1000   (integer prefers code)
//   一点二五美元      → $1.25     (decimal prefers symbol)
//   八九千美元       → $8000~9000 (range prefers symbol)
//   一点二五元       → ¥1.25
//   三千三百八十元五角八分 → ¥3380.58

import Foundation

enum Money {

    /// WeText data/money/symbol.tsv — Chinese currency name to symbol.
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
        "元": "¥",
    ]

    /// WeText data/money/code.tsv — names rewritten to a code.
    static let codePrefix: [String: String] = [
        "美元": "USD",
        "英镑": "GBP",
        "澳元": "A$",
        "加元": "CAD",
        "港元": "HKD",
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

    /// Currencies that always render as symbol (even for plain integer).
    static let symbolOnlyForInteger: Set<String> = ["英镑"]

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = Money.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
