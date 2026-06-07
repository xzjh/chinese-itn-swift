// Math.swift
// Math expression normalization.
// Ported from WeTextProcessing itn/chinese/rules/math.py +
// data/math/operator.tsv (Apache-2.0).
//
// WeText pattern (math.py:30):
//     tagger = number + (operator + number).plus
// Operator table:
//     乘 → ×, 减 → -, 加 → +, 比 → :, 等于 → =, 除 → ÷
//     到 is treated as a range connector controlled by rangeOutputStyle.
//
// Recognition logic lives in Taggers.swift (`MathNormalize.tag`).

import Foundation

enum MathNormalize {

    /// WeText operator.tsv mapping.
    static let operatorMap: [String: String] = [
        "乘": "×",
        "减": "-",
        "到": "~",
        "加": "+",
        "比": ":",
        "等于": "=",
        "除": "÷",
    ]

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = MathNormalize.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
