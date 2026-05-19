// ChineseITN.swift
// Public API. Apply inverse text normalization to Chinese transcript.
//
// Pipeline (lattice / shortest-path architecture):
//   1. Whitelist wraps the entire input — idiom phrases are replaced
//      with PUA placeholders so subsequent taggers can't break them.
//   2. Every other module is a "tagger": it scans the input and emits
//      Candidate edges (startIdx, endIdx, output, weight) for every
//      substring it can normalize.
//   3. A Char fallback tagger emits one identity-edge per char with
//      high cost (100), guaranteeing the lattice has full coverage.
//   4. Lattice.bestPath runs a topological-DP shortest-path over the
//      DAG of candidates and returns the lowest-cost coverage.
//   5. Whitelist placeholders are restored.
//   6. Optional filler removal (呃, 啊).
//
// No local heuristics decide "should module X claim this span or let
// module Y try" — that decision is made globally by the cost-weighted
// DAG, mirroring WeText's Pynini FST composition.

import Foundation

public enum ChineseITN {

    /// Apply the full ITN pipeline to `text` with the given config.
    /// Whitelist terms are protected throughout; all transforms run
    /// inside the protected scope.
    public static func normalize(_ text: String,
                                 config: ChineseITNConfig = .default) -> String {
        Whitelist.protected(text) { protectedText in
            let chars = Array(protectedText)
            var candidates: [Candidate] = []
            candidates += Cardinal.tag(chars, config: config)
            candidates += Decimal.tag(chars, config: config)
            candidates += SpecialCardinal.tag(chars, config: config)
            candidates += DateNormalize.tag(chars, config: config)
            candidates += TimeNormalize.tag(chars, config: config)
            candidates += Fraction.tag(chars, config: config)
            candidates += Money.tag(chars, config: config)
            candidates += Measure.tag(chars, config: config)
            candidates += MathNormalize.tag(chars, config: config)
            candidates += LicensePlate.tag(chars, config: config)
            candidates += Electronic.tag(chars, config: config)
            var out = Lattice.bestPath(chars: chars, candidates: candidates)
            if config.removeInterjections {
                out = removeFillers(out)
            }
            return out
        }
    }

    /// WeText `data/default/blacklist.tsv` — interjection fillers
    /// removed when `remove_interjections=True`.
    private static let fillers: Set<Character> = ["呃", "啊"]

    private static func removeFillers(_ text: String) -> String {
        String(text.filter { !fillers.contains($0) })
    }
}
