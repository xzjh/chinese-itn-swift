// Measure.swift
// Cardinal / decimal + unit binding.
// Ported from WeTextProcessing itn/chinese/rules/measure.py +
// data/measure/units_en.tsv + data/measure/units_zh.tsv (Apache-2.0).
//
// Recognition logic lives in Taggers.swift (`Measure.tag`).
//
// Examples:
//   一千克            → 1kg
//   重达二十五千克     → 重达25kg
//   三百二十四点七五克 → 324.75g
//   最高气温三十八摄氏度 → 最高气温38°C
//   实际面积一百二十平方米 → 实际面积120m²
//   每小时十千米       → 10km/h
//   十一到一百千米每小时 → 11~100km/h
//   三百九十九三盒     → 3993盒  (unit_sp_case1)

import Foundation

enum Measure {

    /// WeText data/measure/units_en.tsv — Chinese unit name to
    /// scientific abbreviation.
    static let unitMap: [String: String] = [
        "万亿焦耳": "tj",
        "万伏特": "Wv",
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

    /// WeText data/measure/units_zh.tsv — Chinese 量词/单位 that keep
    /// the Chinese form in output (number arabize, unit text stays).
    /// Full 191-entry list from WeTextProcessing (Apache-2.0).
    static let unitChineseKept: [String] = [
        "年来", "年前", "年后", "年内", "年之前", "年之后",
        "人", "篇", "帧", "把", "封", "艘", "套", "段", "匹",
        "张", "座", "回", "场", "尾", "条", "个", "首", "阙",
        "阵", "网", "炮", "顶", "丘", "棵", "只", "支", "袭",
        "辆", "挑", "担", "颗", "壳", "窠", "曲", "墙", "群",
        "腔", "砣", "客", "贯", "扎", "捆", "刀", "令", "手",
        "罗", "坡", "山", "岭", "江", "溪", "钟", "队", "单",
        "双", "对", "口", "头", "脚", "板", "跳", "枝", "件",
        "贴", "针", "线", "管", "名", "位", "身", "堂", "课",
        "本", "页", "家", "户", "层", "丝", "毫", "厘", "分",
        "钱", "斤", "铢", "石", "钧", "锱", "忽", "克",
        "寸", "尺", "丈", "里", "寻", "常", "铺", "程", "米",
        "撮", "勺", "合", "升", "斗", "盘", "碗", "碟", "叠",
        "桶", "笼", "盆", "盒", "杯", "斛", "锅", "簋", "篮",
        "罐", "瓶", "壶", "卮", "盏", "箩", "箱", "煲", "啖",
        "袋", "钵", "季", "年", "月", "日", "刻", "时", "周",
        "天", "秒", "旬", "纪", "岁", "世", "更", "夜", "春",
        "夏", "秋", "冬", "代", "伏", "辈", "丸", "泡", "粒",
        "幢", "堆", "根", "道", "面", "片", "块", "架",
        "角", "毛", "字", "元", "两", "两米饭", "两酒", "吨",
        "顿", "牛", "次", "号", "亩",
    ]

    /// Subset of `unitMap` keys that name a duration. Gated by
    /// `enableTimeEnglishMapping` so callers can opt to keep these
    /// units Chinese ("二十分钟" → "20分钟" instead of "20min") while
    /// other unit mappings still apply.
    static let timeUnits: Set<String> = [
        "分钟", "小时", "毫秒", "微秒", "纳秒", "皮秒", "秒",
    ]

    /// Look up a unit name and return its output form (arabized
    /// abbreviation OR kept Chinese), or nil if not a unit. When
    /// `enableTimeEnglishMapping` is false, time-unit subset stays
    /// Chinese (output equals input).
    static func resolveUnit(_ cn: String,
                            enableTimeEnglish: Bool = true) -> String? {
        if !enableTimeEnglish && timeUnits.contains(cn) {
            return cn
        }
        if let en = unitMap[cn] { return en }
        if unitChineseKept.contains(cn) { return cn }
        return nil
    }

    static let allUnits: [String] = Array(unitMap.keys) + unitChineseKept

    /// All units sorted longest-first (for left-to-right regex /
    /// alternation matching).
    static let unitsSortedLongestFirst: [String] = allUnits
        .sorted { $0.count > $1.count }

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = Measure.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
