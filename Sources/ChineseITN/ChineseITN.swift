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
            // Decimal must run BEFORE Cardinal, otherwise Cardinal's
            // scanner consumes the X点Y as separate runs.
            t = Decimal.normalize(t)
            t = Cardinal.normalize(t)
            return t
        }
    }
}
