// Electronic.swift
// URL / email normalization (spaced-spoken form → joined).
// Ported from fun_text_processing
// inverse_text_normalization/zh/taggers/electronic.py (MIT).
//
// Recognition logic lives in Taggers.swift (`Electronic.tag`).

import Foundation

enum Electronic {

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = Electronic.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
