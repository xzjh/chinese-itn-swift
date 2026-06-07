// Fraction.swift
// Fraction normalization. WeText behavior (rules/fraction.py +
// rules/measure.py percent path):
//
//   百分(之)?X → X%
//   百分(之)?X点Y → X.Y%
//   百分(之)?X到(百分之)?Y → X%到Y% / X%~Y%
//   X分之Y → Y/X
//   负X分之Y → -Y/X
//
// Recognition logic lives in Taggers.swift (`Fraction.tag`).
// This file is a thin module-level normalize wrapper.

import Foundation

enum Fraction {

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = Fraction.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
