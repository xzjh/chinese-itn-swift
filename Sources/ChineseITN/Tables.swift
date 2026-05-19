// Tables.swift
// Lookup tables ported from WeTextProcessing's TSV data files
// (Apache 2.0) under itn/chinese/data/.

import Foundation

/// Single Chinese digit characters → ASCII digit. Includes
/// traditional + financial variants and 幺/两/〇/洞.
let digitMap: [Character: Character] = [
    "零": "0", "〇": "0", "洞": "0",
    "一": "1", "幺": "1", "壹": "1",
    "二": "2", "两": "2", "兩": "2", "贰": "2", "貳": "2",
    "三": "3", "叁": "3", "參": "3",
    "四": "4", "肆": "4",
    "五": "5", "伍": "5",
    "六": "6", "陆": "6", "陸": "6",
    "七": "7", "柒": "7",
    "八": "8", "捌": "8",
    "九": "9", "玖": "9",
]

/// Reverse lookup: any character we recognize as a digit.
let digitChars: Set<Character> = Set(digitMap.keys)

/// Unit characters and their multipliers.
let unitMap: [Character: Int] = [
    "十": 10,
    "百": 100,
    "千": 1_000,
    "万": 10_000,
    "萬": 10_000,
    "亿": 100_000_000,
    "億": 100_000_000,
]

/// Whitelist: phrases that must never be transformed. From
/// WeText's data/default/whitelist.tsv (82 entries) plus a few
/// hush·hush-flavor expansions.
let whitelistTerms: [String] = [
    // From WeText whitelist.tsv (idioms + common collocations)
    "三七二十一", "一共", "一个", "一下", "一些", "一起", "一会",
    "一路", "二维码", "慢一点", "一般", "统一",
    "星期一", "星期二", "星期三", "星期四", "星期五", "星期六",
    "星期天", "星期日",
    "一年一度", "一点一滴", "三心二意", "阳春三月", "七嘴八舌",
    "四分五裂", "七荤八素", "三纲五常", "三姑六婆", "四大皆空",
    "五体投地", "六神无主", "七窍生烟", "八面玲珑", "九牛一毛",
    "十拿九稳",
    "百闻不如一见", "百思不得其解", "千变万化", "千方百计",
    "千头万绪", "千言万语", "万紫千红", "万事如意", "万无一失",
    "亿万富翁", "一帆风顺", "一鸣惊人", "一举两得", "一目了然",
    "一丝不苟", "一刻千金", "一鼓作气", "二话不说", "三言两语",
    "三长两短", "四面八方", "五湖四海", "六亲不认", "七上八下",
    "八仙过海", "九霄云外", "十全十美", "百年大计", "百战百胜",
    "千古一帝", "千篇一律", "万象更新", "万家灯火",
    "一杯", "一壶",
    // Place names / proper nouns
    "九寨沟", "三国演义", "水浒传",
]

/// Ordinal prefixes — "第" + cardinal: keep cardinal in Chinese?
/// WeText converts; we follow.

/// Currency suffix → symbol mapping. Used by Money module.
let currencyMap: [String: String] = [
    "美金": "$",
    "美元": "$",
    "欧元": "€",
    "英镑": "£",
    "日元": "¥",
    "人民币": "¥",
]

/// Currency suffix → kept as Chinese (just digit normalization).
let currencyKeptChinese: Set<String> = [
    "块钱", "元", "块", "毛", "分", "角",
]

/// Time periods (noon prefixes).
let noonMap: [String: String] = [
    "上午": "a.m.",
    "早上": "a.m.",
    "早晨": "a.m.",
    "下午": "p.m.",
    "晚上": "p.m.",
    "傍晚": "p.m.",
]
