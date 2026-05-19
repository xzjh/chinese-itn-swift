// Whitelist.swift
// Protect idioms / fixed phrases from any ITN transformation by
// replacing them with PUA placeholders, applying transforms, then
// restoring.

import Foundation

enum Whitelist {

    /// Wrap `body` so each occurrence of a whitelist phrase in `text`
    /// is invisible to `body`'s transforms and restored verbatim
    /// afterward. Longer phrases protected first to avoid prefix
    /// shadowing.
    static func protected(_ text: String, body: (String) -> String) -> String {
        let sorted = whitelistTerms.sorted { $0.count > $1.count }
        var placeholders: [(token: String, original: String)] = []
        var working = text

        for (idx, term) in sorted.enumerated() {
            if working.contains(term) {
                let token = "\u{E000}\(idx)\u{E001}"
                working = working.replacingOccurrences(of: term, with: token)
                placeholders.append((token, term))
            }
        }

        let processed = body(working)

        var out = processed
        for (token, original) in placeholders {
            out = out.replacingOccurrences(of: token, with: original)
        }
        return out
    }
}
