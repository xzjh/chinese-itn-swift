// LicensePlate.swift
// China license plate normalization (京A12345 form).
// Recognition logic lives in Taggers.swift (`LicensePlate.tag`).

import Foundation

enum LicensePlate {

    /// Chinese provinces that prefix a license plate. From WeText
    /// data/license_plate/province.tsv (31 entries).
    static let provinceChars: Set<Character> = [
        "京", "津", "沪", "渝", "冀", "豫", "云", "辽",
        "黑", "湘", "皖", "鲁", "新", "苏", "浙", "赣",
        "鄂", "桂", "甘", "晋", "蒙", "陕", "吉", "闽",
        "贵", "粤", "青", "藏", "川", "宁", "琼",
    ]

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = LicensePlate.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
