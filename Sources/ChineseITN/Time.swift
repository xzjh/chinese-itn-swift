// Time.swift
// Time expression normalization.
// Ported from WeTextProcessing itn/chinese/rules/time.py +
// data/time/{hour,minute,second,noon}.tsv (Apache-2.0).
//
// Recognition logic lives in Taggers.swift (`TimeNormalize.tag`).
// This file holds the lookup tables and a thin module-level
// normalize wrapper that runs the tagger through the Lattice solver.
//
// WeText time tagger (time.py:30):
//   tagger = (noon)? + hour + minute + (delete'分')? + (second)?
//   default compact verbalize = hour + ':' + minute + (':' + second)? + noon?
//
// Examples per WeText official test/data/time.txt (we differ from
// WeText in adding a space before a.m./p.m. per NIST SP 811 §10.3):
//   两点零二分           → 2:02
//   十三点十分三十六秒    → 13:10:36
//   上午一点零二分三十六秒 → 1:02:36 a.m.
//   早上一点零二          → 1:02 a.m.
//   零点十分              → 00:10
//   八点半                → 8:30
//
// `ChineseITNConfig.temporalOutputStyle` can instead emit Chinese
// numeric units (`8点30分`) or preserve the spoken Chinese span.

import Foundation

enum TimeNormalize {

    /// WeText hour.tsv — one representation per hour.
    static let hourMap: [String: String] = [
        "零点": "00",
        "一点": "1",
        "两点": "2",
        "三点": "3",
        "四点": "4",
        "五点": "5",
        "六点": "6",
        "七点": "7",
        "八点": "8",
        "九点": "9",
        "十点": "10",
        "十一点": "11",
        "十二点": "12",
        "十三点": "13",
        "十四点": "14",
        "十五点": "15",
        "十六点": "16",
        "十七点": "17",
        "十八点": "18",
        "十九点": "19",
        "二十点": "20",
        "二十一点": "21",
        "二十二点": "22",
        "二十三点": "23",
        "二十四点": "24",
    ]

    /// WeText minute.tsv (60 entries).
    static let minuteMap: [String: String] = {
        var m: [String: String] = [:]
        m["半"] = "30"
        let chars1to9 = ["一","二","三","四","五","六","七","八","九"]
        let chars0 = "零"
        for (i, c) in chars1to9.enumerated() {
            m["\(chars0)\(c)"] = String(format: "%02d", i + 1)
        }
        m["十"] = "10"
        for (i, c) in chars1to9.enumerated() {
            m["十\(c)"] = String(format: "%02d", 10 + i + 1)
        }
        for tens in 2...5 {
            let tensChar = chars1to9[tens - 1]
            m["\(tensChar)十"] = String(format: "%02d", tens * 10)
            for (i, c) in chars1to9.enumerated() {
                m["\(tensChar)十\(c)"] = String(format: "%02d", tens * 10 + i + 1)
            }
        }
        return m
    }()

    /// WeText second.tsv — same shape as minuteMap with 秒 suffix.
    static let secondMap: [String: String] = {
        var m: [String: String] = ["": "00"]
        let chars1to9 = ["一","二","三","四","五","六","七","八","九"]
        for (i, c) in chars1to9.enumerated() {
            m["\(c)秒"] = String(format: "%02d", i + 1)
        }
        m["十秒"] = "10"
        for (i, c) in chars1to9.enumerated() {
            m["十\(c)秒"] = String(format: "%02d", 10 + i + 1)
        }
        for tens in 2...5 {
            let tensChar = chars1to9[tens - 1]
            m["\(tensChar)十秒"] = String(format: "%02d", tens * 10)
            for (i, c) in chars1to9.enumerated() {
                m["\(tensChar)十\(c)秒"] = String(format: "%02d", tens * 10 + i + 1)
            }
        }
        return m
    }()

    /// WeText noon.tsv — period-of-day prefixes.
    static let noonMapLocal: [String: String] = [
        "上午": "a.m.",
        "早上": "a.m.",
        "早晨": "a.m.",
        "下午": "p.m.",
        "晚上": "p.m.",
        "傍晚": "p.m.",
    ]

    /// Normalize using only this module's tagger + Char fallback.
    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = TimeNormalize.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
