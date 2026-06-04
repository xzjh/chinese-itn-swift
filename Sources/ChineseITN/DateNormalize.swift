// DateNormalize.swift
// Year / Month / Day normalization. Default compact output matches
// WeTextProcessing itn/chinese/rules/date.py:
//
//   二零零八年八月八日 → 2008/08/08
//   二零零八年八月     → 2008/08
//   八月八日           → 08/08
//   二零零八年         → 2008年   (year-only standalone keeps 年)
//   公元一六八年       → 公元168年
//
// `ChineseITNConfig.temporalOutputStyle` can instead emit Chinese
// numeric units (`2008年8月8日`) or preserve the spoken Chinese span.
//
// Recognition logic lives in Taggers.swift (`DateNormalize.tag`).

import Foundation

enum DateNormalize {

    static func normalize(_ text: String,
                          config: ChineseITNConfig = .default) -> String {
        let chars = Array(text)
        let candidates = DateNormalize.tag(chars, config: config)
        return Lattice.bestPath(chars: chars, candidates: candidates)
    }
}
