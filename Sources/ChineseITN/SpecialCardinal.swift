// SpecialCardinal.swift
// Spoken-language number patterns that don't fit regular positional
// reading. Product default preserves these vague ranges verbatim;
// `.spokenRangeStyle = .expand` turns them into explicit ranges.
// Ported from WeTextProcessing data/number/special_tilde.tsv +
// special_dash.tsv (Apache-2.0).
//
// special_tilde standalone or with 万/亿:
//   三四       → 3~4
//   三五百     → 300~500
//   三四万     → 3~4万
//   三四十万   → 30~40万
//
// special_dash inside cardinal compositions:
//   十五六     → 15到16 / 15~16
//   四十五六   → 45到46 / 45~46
//   七百三四十 → 730到740 / 730~740
//   一万六七   → 16000到17000 / 16000~17000
//
// Recognition logic lives in Taggers.swift (`SpecialCardinal.tag`).

import Foundation

enum SpecialCardinal {

    /// Base entries — joiner ("~" or "-") added per context.
    static let tildePairs: [String: String] = [
        "一二": "1~2", "二三": "2~3", "三四": "3~4", "三五": "3~5",
        "四五": "4~5", "五六": "5~6", "六七": "6~7", "七八": "7~8",
        "八九": "8~9",
        "一二十": "10~20", "二三十": "20~30", "三四十": "30~40",
        "三五十": "30~50", "四五十": "40~50", "五六十": "50~60",
        "六七十": "60~70", "七八十": "70~80", "八九十": "80~90",
        "一二百": "100~200", "一两百": "100~200",
        "二三百": "200~300", "两三百": "200~300",
        "三四百": "300~400", "三五百": "300~500",
        "四五百": "400~500", "五六百": "500~600",
        "六七百": "600~700", "七八百": "700~800", "八九百": "800~900",
        "一二千": "1000~2000", "一两千": "1000~2000",
        "二三千": "2000~3000", "两三千": "2000~3000",
        "三四千": "3000~4000", "三五千": "3000~5000",
        "四五千": "4000~5000", "五六千": "5000~6000",
        "六七千": "6000~7000", "七八千": "7000~8000",
        "八九千": "8000~9000",
    ]

    /// Same keys, dash separator.
    static let dashPairs: [String: String] = {
        var m: [String: String] = [:]
        for (k, v) in tildePairs {
            m[k] = v.replacingOccurrences(of: "~", with: "-")
        }
        return m
    }()

    static func formatTildeRange(_ raw: String,
                                 config: ChineseITNConfig) -> String {
        raw.replacingOccurrences(of: "~", with: config.rangeConnector)
    }

    static func formatDashRange(_ raw: String,
                                config: ChineseITNConfig) -> String {
        let parts = raw.split(separator: "-", maxSplits: 1,
                              omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return raw.replacingOccurrences(of: "-", with: config.rangeConnector)
        }
        let left = String(parts[0])
        let rightSuffix = String(parts[1])
        guard !left.isEmpty, !rightSuffix.isEmpty,
              left.allSatisfy(\.isNumber),
              rightSuffix.allSatisfy(\.isNumber) else {
            return raw.replacingOccurrences(of: "-", with: config.rangeConnector)
        }
        let right: String
        if rightSuffix.count < left.count {
            let prefixLen = left.count - rightSuffix.count
            right = String(left.prefix(prefixLen)) + rightSuffix
        } else {
            right = rightSuffix
        }
        return "\(left)\(config.rangeConnector)\(right)"
    }

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = SpecialCardinal.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
