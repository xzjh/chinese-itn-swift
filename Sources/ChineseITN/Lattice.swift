// Lattice.swift
// Weighted token graph + shortest-path solver, replacing the previous
// sequential regex pipeline.
//
// Why this exists:
//   WeTextProcessing composes all its taggers into a single Pynini FST
//   with per-tagger weights (Date 1.02, Money 1.04, Fraction/Measure/
//   Time 1.05, Cardinal 1.06, Math 1.10, LicensePlate 1.0, Char 100,
//   Whitelist 1.01). A sentence is "covered" by tokens (each token is
//   one tagger's match over a substring), and the FST picks the
//   coverage with the lowest total cost. That's how WeText distinguishes
//   between competing parses — e.g. "四点零八个G" prefers Measure
//   (decimal+量词) over Time (4:08) because Measure can cover one more
//   char (个) and the extra Char-cost outweighs Time's slight cost edge.
//
// Our previous regex pipeline ran each module in fixed order with
// local heuristics (lookbehinds, lookaheads, ordering tweaks) to
// approximate the FST's behavior. That worked for the test corpus
// but didn't generalize — every new edge case needed a new heuristic.
// This file replaces that with a faithful weighted-graph model.
//
// Algorithm:
//   1. Each module is a "tagger": given the input string, it emits
//      zero or more Candidate edges. Each Candidate is
//      (startIdx, endIdx, output, weight). Multiple overlapping
//      candidates are allowed.
//   2. A baseline Char tagger emits one identity-edge per position
//      with high cost (100), guaranteeing full coverage.
//   3. The Lattice is a DAG with nodes 0...N (one per char-boundary)
//      and edges from each Candidate. We run Dijkstra (or topological
//      DP since the graph is a DAG) from node 0 to node N, picking the
//      lowest-cost path.
//   4. Reconstruct the path and concatenate output strings.

import Foundation

/// A single candidate edge emitted by a tagger.
/// - `startIdx` / `endIdx`: half-open char range covered, in chars
///   (NOT bytes / UTF-16 units). Use `Array(text)` to get a
///   char-indexed view.
/// - `output`: the string this candidate produces.
/// - `weight`: tagger cost. Lower = preferred.
/// - `source`: short name of the tagger (for debugging).
struct Candidate {
    let startIdx: Int
    let endIdx: Int
    let output: String
    let weight: Double
    let source: String
}

/// Per-tagger weights, mirroring WeTextProcessing
/// itn/chinese/inverse_normalizer.py:55-65 add_weight() args.
enum TaggerWeight {
    static let licensePlate: Double = 1.0
    static let whitelist: Double = 1.01
    static let date: Double = 1.02
    static let money: Double = 1.04
    static let fraction: Double = 1.05
    static let measure: Double = 1.05
    static let time: Double = 1.05
    static let cardinal: Double = 1.06
    static let math: Double = 1.10
    static let char: Double = 100.0
    /// Bonus for Electronic (URL) — not in WeText; we set it equal to
    /// LicensePlate (highest priority) since URLs are highly specific.
    static let electronic: Double = 1.0
    /// Special cardinal (special_tilde / special_dash) shares weight
    /// with Cardinal per WeText cardinal.py — they're unioned into
    /// the same `number` definition.
    static let specialCardinal: Double = 1.06
}

enum Lattice {

    /// Run the shortest-path algorithm and return the best output.
    /// `chars` is the input as an array of Characters (so indices are
    /// char-indexed, not byte-indexed).
    /// `candidates` is the union of all taggers' candidates.
    static func bestPath(chars: [Character], candidates: [Candidate]) -> String {
        let n = chars.count
        if n == 0 { return "" }

        // Always include identity Char edges so every position has a
        // valid outgoing edge, guaranteeing path existence.
        var edges = candidates
        for i in 0..<n {
            edges.append(Candidate(
                startIdx: i, endIdx: i + 1,
                output: String(chars[i]),
                weight: TaggerWeight.char,
                source: "char"
            ))
        }

        // Group edges by start node.
        var edgesByStart: [[Candidate]] = Array(repeating: [], count: n)
        for e in edges where e.startIdx >= 0 && e.startIdx < n
            && e.endIdx > e.startIdx && e.endIdx <= n {
            edgesByStart[e.startIdx].append(e)
        }

        // Topological-order DP since the graph is a left-to-right DAG.
        // dist[i] = lowest cost from 0 to node i.
        // back[i] = the edge that achieves that cost.
        var dist: [Double] = Array(repeating: .infinity, count: n + 1)
        var back: [Candidate?] = Array(repeating: nil, count: n + 1)
        dist[0] = 0

        for i in 0..<n {
            guard dist[i].isFinite else { continue }
            for e in edgesByStart[i] {
                let newCost = dist[i] + e.weight
                if newCost < dist[e.endIdx] {
                    dist[e.endIdx] = newCost
                    back[e.endIdx] = e
                }
            }
        }

        // Reconstruct path from N back to 0.
        var pieces: [String] = []
        var cursor = n
        while cursor > 0 {
            guard let edge = back[cursor] else {
                // No path — shouldn't happen because Char edges cover
                // everything. Defensive fallback: emit the char directly.
                pieces.append(String(chars[cursor - 1]))
                cursor -= 1
                continue
            }
            pieces.append(edge.output)
            cursor = edge.startIdx
        }
        return pieces.reversed().joined()
    }
}
