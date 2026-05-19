// Decimal.swift
// "X点Y → X.Y" conversion. Recognition logic lives in
// Taggers.swift (`Decimal.tag`). This file is a thin module-level
// normalize wrapper that runs the tagger through the Lattice solver.

import Foundation

enum Decimal {

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = Decimal.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
