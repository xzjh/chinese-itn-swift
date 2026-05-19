// ChineseITN.swift
// Public API. Apply inverse text normalization to Chinese transcript.

import Foundation

public enum ChineseITN {

    /// Apply the full ITN pipeline to `text`. Whitelist terms are
    /// protected throughout; all transforms run inside the protected
    /// scope and the result has whitelist terms restored verbatim.
    public static func normalize(_ text: String) -> String {
        Whitelist.protected(text) { protectedText in
            var t = protectedText
            // Order matters: more specific patterns first so they
            // claim their tokens before generic modules consume them.
            t = Electronic.normalize(t)
            t = LicensePlate.normalize(t)
            t = DateNormalize.normalize(t)
            // Time MUST run before Decimal — "X点Y" is time when Y is
            // in minute.tsv (e.g. "零八"=08); else falls through to
            // Decimal. Matches WeText FST weighted priority.
            t = TimeNormalize.normalize(t)
            t = MathNormalize.normalize(t)
            t = Fraction.normalize(t)
            t = Money.normalize(t)
            t = Measure.normalize(t)
            t = Decimal.normalize(t)
            t = Cardinal.normalize(t)
            return t
        }
    }
}
