// Electronic.swift
// URL / email normalization.
// Ported from fun_text_processing's
// inverse_text_normalization/zh/taggers/electronic.py (MIT).
//
// fun's tagger reconstructs URLs / emails from spaced-spoken form:
//   "h t t p 冒号斜杆斜杠 w w w 点 baidu 点 com"
//     → "h t t p 冒号斜杆斜杠 www.baidu.com"
//
// fun keeps the protocol prefix verbatim ("h t t p 冒号斜杆斜杠 ")
// and concatenates the domain part (server + "." + tld), removing
// spaces between letter chars.
//
// Limitations: this initial port only handles the "w w w 点 X 点 Y"
// pattern (URL with www and 2-level domain). Email reconstruction
// ("X 艾特 Y") and HTTP-protocol expansion are NOT yet covered.

import Foundation

enum Electronic {

    /// Match spaced "w w w 点 SERVER 点 TLD" → "www.SERVER.TLD"
    /// SERVER and TLD are runs of single letters separated by spaces
    /// OR a contiguous letter token.
    private static let _wwwRE = try! NSRegularExpression(
        pattern: "w w w 点 ([a-zA-Z]+(?: [a-zA-Z])*) 点 ([a-zA-Z]+(?: [a-zA-Z])*)"
    )

    static func normalize(_ text: String) -> String {
        regexReplace(text, regex: _wwwRE) { match, ns in
            let serverRaw = ns.substring(with: match.range(at: 1))
            let tldRaw = ns.substring(with: match.range(at: 2))
            let server = serverRaw.replacingOccurrences(of: " ", with: "")
            let tld = tldRaw.replacingOccurrences(of: " ", with: "")
            return "www.\(server).\(tld)"
        }
    }
}
