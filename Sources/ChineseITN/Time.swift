// Time.swift
// Time expression normalization.
// Ported from WeTextProcessing itn/chinese/rules/time.py +
// data/time/{hour,minute,second,noon}.tsv (Apache-2.0).
//
// WeText time tagger (time.py:30):
//   tagger = (noon)? + hour + minute + (delete'分')? + (second)?
//   verbalize = hour + ':' + minute + (':' + second)? + noon?
//
// Hour mapping: "一点"→"1", ..., "九点"→"9", "零点"→"00",
//   "一点"→"01"..."九点"→"09" (padded variants), "十点"→"10", ..., "二十四点"→"24"
// Minute mapping (from data/time/minute.tsv): "半"→"30", "零一"→"01" through
//   "五十九"→"59" with all forms covered.
// Noon mapping: "上午/早上/早晨"→"a.m.", "下午/晚上/傍晚"→"p.m."
//
// Examples per WeText official test/data/time.txt:
//   两点零二分           → 2:02
//   十三点十分三十六秒    → 13:10:36
//   上午一点零二分三十六秒 → 1:02:36a.m.
//   早上一点零二          → 1:02a.m.
//   零点十分              → 00:10
//   八点半                → 8:30

import Foundation

enum TimeNormalize {

    /// WeText hour.tsv — first 9 entries plus 零点/十-二十四 (single
    /// representation per hour). Padded variants (一点→01 etc.) are
    /// FST weight tiebreakers, not behavior changes for our scan.
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

    /// WeText minute.tsv (60 entries). Order matters for longest-match.
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

    /// WeText second.tsv (60 entries). Same shape as minuteMap but
    /// each spoken form ends in 秒.
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

    private static let noonMapLocal: [String: String] = [
        "上午": "a.m.",
        "早上": "a.m.",
        "早晨": "a.m.",
        "下午": "p.m.",
        "晚上": "p.m.",
        "傍晚": "p.m.",
    ]

    /// Match: (noon)? + hour + minute? + (分)? + (second)?
    /// Hour, minute, second from their respective lookup tables.
    private static let _re: NSRegularExpression = {
        let hours = hourMap.keys.sorted { $0.count > $1.count }
        let minutes = minuteMap.keys.sorted { $0.count > $1.count }
        let seconds = secondMap.keys.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        let noons = noonMapLocal.keys.sorted { $0.count > $1.count }
        let hourAlt = hours.joined(separator: "|")
        let minuteAlt = minutes.joined(separator: "|")
        let secondAlt = seconds.joined(separator: "|")
        let noonAlt = noons.joined(separator: "|")
        return try! NSRegularExpression(
            pattern: "(\(noonAlt))?(\(hourAlt))(\(minuteAlt))?分?(\(secondAlt))?"
        )
    }()

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _re) { match, ns in
            let original = ns.substring(with: match.range)
            let noonRange = match.range(at: 1)
            let hourRange = match.range(at: 2)
            let minuteRange = match.range(at: 3)
            let secondRange = match.range(at: 4)

            let noonStr = noonRange.location != NSNotFound
                ? ns.substring(with: noonRange) : ""
            let hourStr = ns.substring(with: hourRange)
            let minuteStr = minuteRange.location != NSNotFound
                ? ns.substring(with: minuteRange) : ""
            let secondStr = secondRange.location != NSNotFound
                ? ns.substring(with: secondRange) : ""

            // No minute and no second means just "X点" alone (Cardinal
            // territory) — pass through, Cardinal will handle the digit
            // conversion later.
            if minuteStr.isEmpty && secondStr.isEmpty {
                return original
            }

            guard let h = hourMap[hourStr] else { return original }
            var out = h
            if !minuteStr.isEmpty {
                guard let m = minuteMap[minuteStr] else { return original }
                out += ":\(m)"
            } else {
                out += ":00"
            }
            if !secondStr.isEmpty {
                guard let s = secondMap[secondStr] else { return original }
                out += ":\(s)"
            }
            if let noon = noonMapLocal[noonStr] {
                out += noon
            }
            return out
        }
    }
}
