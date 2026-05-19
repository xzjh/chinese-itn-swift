// Money.swift
// Money / currency normalization.
// Ported from WeTextProcessing itn/chinese/rules/money.py +
// data/money/symbol.tsv (Apache-2.0).
//
// WeText money.py rule:
//   tagger = value(number) + currency(code|symbol) + decimal?
//   verbalizer = currency + value + decimal
// Effective behavior: "X<currency>" rearranges to "<symbol>X" when
// currency is in symbol.tsv; "X<currency>" stays as "<digit_X><currency>"
// when not in symbol mapping (Cardinal alone handles digit part).
//
// Examples per data/money/symbol.tsv:
//   两百欧元   → €200    (欧元 → €)
//   一千美元   → $1000   (美元 → $)
//   五百英镑   → £500    (英镑 → £)
//   五十块钱   → 50块钱  (块钱 not in symbol.tsv; Cardinal handles)

import Foundation

enum Money {

    /// Currency suffix → symbol prefix.
    /// Subset of WeText data/money/symbol.tsv that's
    /// unambiguous and likely in ASR output. The "元 → ¥" rule from
    /// symbol.tsv is INTENTIONALLY excluded — "元" is too generic
    /// and would mis-fire on currency contexts where Chinese readers
    /// expect to see "X元" not "¥X".
    private static let symbolPrefix: [String: String] = [
        "美元": "$",
        "英镑": "£",
        "欧元": "€",
        "泰铢": "฿",
        "朝鲜园": "₩",
        "韩元": "₩",
        "日元": "¥",
        "印度卢比": "₹",
        "越南东": "₫",
        "土耳其里拉": "₺",
        "卢布": "₽",
    ]

    /// Match cardinal expression + currency suffix.
    private static let _re: NSRegularExpression = {
        let alternation = symbolPrefix.keys.joined(separator: "|")
        return try! NSRegularExpression(
            pattern: "([\(cnCardinalClass)]+)(\(alternation))"
        )
    }()

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let cnVal = ns.substring(with: match.range(at: 1))
            let currency = ns.substring(with: match.range(at: 2))
            guard let symbol = symbolPrefix[currency],
                  let n = Cardinal.parseToInt(cnVal) else {
                return ns.substring(with: match.range)
            }
            return "\(symbol)\(n)"
        }
    }
}
