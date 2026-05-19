// Taggers.swift
// Each ITN module exposes a `tag` function that scans the input and
// emits zero or more Candidate edges with its associated weight.
// The Lattice solver picks the lowest-cost coverage.
//
// Migration strategy: the legacy `Module.normalize(_:)` rewrites stay
// for now (still used by some unit tests). The new `Module.tag(_:)`
// functions duplicate the recognition logic but emit candidates
// instead of doing rewrites. ChineseITN.normalize switches to use
// taggers + lattice; legacy rewrites are deprecated.

import Foundation

// MARK: - Date tagger

extension DateNormalize {

    /// Emit date candidates per WeText date.py:
    ///   yyyy = digit + (digit|zero)**3   (4-char year)
    ///   yyy  = digit + (digit|zero)**2   (3-char year)
    ///   yy   = (digit|zero)**2           (2-char year)
    ///   date = ((year+month+day) | (year+month) | (month+day)) | year_only
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnDigitSet = Set(cnDigitClass)
        let cnCardSet = Set(cnCardinalClass)

        // For each position, try matching year/month/day combinations.
        for i in 0..<n {
            // Year span: 2-4 cnDigit chars + 年
            for yearLen in [4, 3, 2] {
                let yearEnd = i + yearLen
                guard yearEnd < n, chars[yearEnd] == "年" else { continue }
                let yearStr = String(chars[i..<yearEnd])
                guard yearStr.allSatisfy(cnDigitSet.contains) else { continue }
                let yArabic = String(yearStr.compactMap { digitMap[$0] })
                guard yArabic.count == yearStr.count else { continue }

                // Try year + month + day
                if let (monthEnd, mInt) = matchMonth(chars: chars,
                                                    start: yearEnd + 1) {
                    if let (dayEnd, dInt) = matchDay(chars: chars, start: monthEnd) {
                        out.append(Candidate(
                            startIdx: i,
                            endIdx: dayEnd,
                            output: String(format: "%@/%02d/%02d", yArabic, mInt, dInt),
                            weight: TaggerWeight.date,
                            source: "date"
                        ))
                    }
                    // Year + month
                    out.append(Candidate(
                        startIdx: i,
                        endIdx: monthEnd,
                        output: String(format: "%@/%02d", yArabic, mInt),
                        weight: TaggerWeight.date,
                        source: "date"
                    ))
                }

                // Year only (not followed by month) — but always emit
                // as a candidate; lattice decides via cost.
                let nextIsCardinal = yearEnd + 1 < n
                    && cnCardSet.contains(chars[yearEnd + 1])
                if !nextIsCardinal {
                    out.append(Candidate(
                        startIdx: i,
                        endIdx: yearEnd + 1,
                        output: "\(yArabic)年",
                        weight: TaggerWeight.date,
                        source: "date_year_only"
                    ))
                }
            }

            // Month + day standalone (no year prefix)
            if let (monthEnd, mInt) = matchMonth(chars: chars, start: i) {
                if let (dayEnd, dInt) = matchDay(chars: chars, start: monthEnd) {
                    out.append(Candidate(
                        startIdx: i,
                        endIdx: dayEnd,
                        output: String(format: "%02d/%02d", mInt, dInt),
                        weight: TaggerWeight.date,
                        source: "date_md"
                    ))
                }
            }
        }
        return out
    }

    /// Match a "X月" span starting at `start`. Returns (end-idx-after-月, month-int).
    private static func matchMonth(chars: [Character], start: Int) -> (Int, Int)? {
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        var j = start
        while j < n && cnCardSet.contains(chars[j]) { j += 1 }
        guard j > start, j < n, chars[j] == "月" else { return nil }
        let mStr = String(chars[start..<j])
        guard let mInt = Cardinal.parseToInt(mStr), (1...12).contains(mInt)
        else { return nil }
        return (j + 1, mInt)
    }

    /// Match a "X(日|号|號)" span starting at `start`.
    private static func matchDay(chars: [Character], start: Int) -> (Int, Int)? {
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        var k = start
        while k < n && cnCardSet.contains(chars[k]) { k += 1 }
        guard k > start, k < n,
              chars[k] == "日" || chars[k] == "号" || chars[k] == "號"
        else { return nil }
        let dStr = String(chars[start..<k])
        guard let dInt = Cardinal.parseToInt(dStr), (1...31).contains(dInt)
        else { return nil }
        return (k + 1, dInt)
    }
}

// MARK: - Fraction tagger

extension Fraction {

    /// Emit candidates for: 百分(之)?X / X分之Y / 百分之X到Y range /
    /// 百分之X点Y decimal, with optional sign prefix.
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        let cnDigitSet = Set(cnDigitClass)

        for i in 0..<n {
            // Optional sign prefix
            var signLen = 0
            var signOut = ""
            if i + 1 < n {
                let two = String(chars[i...(i + 1)])
                if let s = Cardinal.signMap[two] { signLen = 2; signOut = s }
            }
            if signLen == 0, let s = Cardinal.signMap[String(chars[i])] {
                signLen = 1; signOut = s
            }

            // 百分(之)?... pattern
            let bStart = i + signLen
            if bStart + 1 < n && chars[bStart] == "百" && chars[bStart + 1] == "分" {
                var valStart = bStart + 2
                if valStart < n && chars[valStart] == "之" { valStart += 1 }

                // Value: cnCard span
                var j = valStart
                while j < n && cnCardSet.contains(chars[j]) { j += 1 }
                if j > valStart {
                    let valStr = String(chars[valStart..<j])
                    let valInt = valStr == "百" ? 100 : Cardinal.parseToInt(valStr)
                    if let v = valInt {
                        // 百分之X (plain) - candidate at endIdx=j
                        out.append(Candidate(
                            startIdx: i,
                            endIdx: j,
                            output: "\(signOut)\(v)%",
                            weight: TaggerWeight.fraction,
                            source: "percent"
                        ))
                        // 百分之X点Y form
                        if j < n && (chars[j] == "点" || chars[j] == "點") {
                            var k = j + 1
                            while k < n && cnDigitSet.contains(chars[k]) { k += 1 }
                            if k > j + 1 {
                                let fracStr = String(chars[(j + 1)..<k])
                                let fracDigits = fracStr.compactMap { digitMap[$0] }
                                if fracDigits.count == fracStr.count {
                                    out.append(Candidate(
                                        startIdx: i,
                                        endIdx: k,
                                        output: "\(signOut)\(v).\(String(fracDigits))%",
                                        weight: TaggerWeight.fraction,
                                        source: "percent_decimal"
                                    ))
                                }
                            }
                        }
                        // 百分之X到Y form (optionally 到百分之Y)
                        if j < n && chars[j] == "到" {
                            var rangeStart = j + 1
                            if rangeStart + 1 < n
                                && chars[rangeStart] == "百"
                                && chars[rangeStart + 1] == "分" {
                                rangeStart += 2
                                if rangeStart < n && chars[rangeStart] == "之" {
                                    rangeStart += 1
                                }
                            }
                            var k = rangeStart
                            while k < n && cnCardSet.contains(chars[k]) { k += 1 }
                            if k > rangeStart {
                                let bStr = String(chars[rangeStart..<k])
                                let bVal = bStr == "百" ? 100 : Cardinal.parseToInt(bStr)
                                if let b = bVal {
                                    out.append(Candidate(
                                        startIdx: i,
                                        endIdx: k,
                                        output: "\(signOut)\(v)~\(b)%",
                                        weight: TaggerWeight.fraction,
                                        source: "percent_range"
                                    ))
                                }
                            }
                        }
                    }
                }
            }

            // X分之Y form
            var j = bStart
            while j < n && cnCardSet.contains(chars[j]) { j += 1 }
            if j > bStart, j + 1 < n, chars[j] == "分", chars[j + 1] == "之" {
                let denomStr = String(chars[bStart..<j])
                let numerStart = j + 2
                var k = numerStart
                while k < n && cnCardSet.contains(chars[k]) { k += 1 }
                if k > numerStart {
                    let numerStr = String(chars[numerStart..<k])
                    if let denom = Cardinal.parseToInt(denomStr),
                       let numer = Cardinal.parseToInt(numerStr) {
                        out.append(Candidate(
                            startIdx: i,
                            endIdx: k,
                            output: "\(signOut)\(numer)/\(denom)",
                            weight: TaggerWeight.fraction,
                            source: "fraction"
                        ))
                    }
                }
            }
        }
        return out
    }
}

// MARK: - Money tagger

extension Money {

    /// Emit candidates per WeText money.py:
    ///   tagger = number + currency + decimal?
    /// Plus tilde/dash range + currency forms.
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        let cnDigitSet = Set(cnDigitClass)

        // All currency keys sorted longest-first
        let currencies = Set(symbolPrefix.keys).union(codePrefix.keys)
        let currenciesSorted = currencies.sorted { $0.count > $1.count }

        for i in 0..<n {
            // Cardinal+currency (with optional decimal payload)
            var j = i
            while j < n && cnCardSet.contains(chars[j]) { j += 1 }
            let numValid: Bool = j > i && {
                let numStr = String(chars[i..<j])
                return Cardinal.parse(numStr) != nil
                    || (numStr.count == 1 && digitChars.contains(numStr.first!))
            }()
            if j > i && numValid {
                let numStr = String(chars[i..<j])

                // Try currency right after num
                for cur in currenciesSorted {
                    if j + cur.count <= n {
                        let candidate = String(chars[j..<(j + cur.count)])
                        if candidate == cur {
                            if let intVal = Cardinal.parseToInt(numStr) {
                                // Single-digit + 元 stays per WeText
                                if cur == "元" && numStr.count == 1,
                                   let ch = numStr.first,
                                   digitChars.contains(ch) {
                                    continue
                                }
                                let prefix = currencyPrefixFor(
                                    cur, hasDecimal: false, hasRange: false)
                                out.append(Candidate(
                                    startIdx: i,
                                    endIdx: j + cur.count,
                                    output: "\(prefix)\(intVal)",
                                    weight: TaggerWeight.money,
                                    source: "money_cardinal"
                                ))
                            }
                        }
                    }
                }

                // Decimal: numStr + 点 + cnDigits + currency
                if j < n && (chars[j] == "点" || chars[j] == "點") {
                    var k = j + 1
                    while k < n && cnDigitSet.contains(chars[k]) { k += 1 }
                    if k > j + 1 {
                        let intVal: Int? = Cardinal.parseToInt(numStr)
                        let fracStr = String(chars[(j + 1)..<k])
                        let fracDigits = fracStr.compactMap { digitMap[$0] }
                        if let intV = intVal, fracDigits.count == fracStr.count {
                            for cur in currenciesSorted {
                                if k + cur.count <= n {
                                    let candidate = String(chars[k..<(k + cur.count)])
                                    if candidate == cur {
                                        let prefix = currencyPrefixFor(
                                            cur, hasDecimal: true, hasRange: false)
                                        out.append(Candidate(
                                            startIdx: i,
                                            endIdx: k + cur.count,
                                            output: "\(prefix)\(intV).\(String(fracDigits))",
                                            weight: TaggerWeight.money,
                                            source: "money_decimal"
                                        ))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 元角分 decimal composition: <num>元<digit>(毛|角)[<digit>分]
            if let (yEnd, yOut) = matchYuanJiaoFen(chars: chars, start: i) {
                out.append(Candidate(
                    startIdx: i,
                    endIdx: yEnd,
                    output: yOut,
                    weight: TaggerWeight.money,
                    source: "money_yjf"
                ))
            }

            // tilde range: tilde key + currency
            for key in tildeKeysSorted {
                if i + key.count <= n {
                    let candidate = String(chars[i..<(i + key.count)])
                    if candidate == key,
                       let val = SpecialCardinal.tildePairs[key] {
                        for cur in currenciesSorted {
                            let curStart = i + key.count
                            if curStart + cur.count <= n {
                                let curCand = String(chars[curStart..<(curStart + cur.count)])
                                if curCand == cur {
                                    let prefix = currencyPrefixFor(
                                        cur, hasDecimal: false, hasRange: true)
                                    out.append(Candidate(
                                        startIdx: i,
                                        endIdx: curStart + cur.count,
                                        output: "\(prefix)\(val)",
                                        weight: TaggerWeight.money,
                                        source: "money_tilde"
                                    ))
                                }
                            }
                        }
                    }
                }
            }

            // dash range: 十+pair / digit+十+pair / digit+百+3pair + currency
            for (form, lead, key) in dashFormsAt(chars: chars, pos: i) {
                let endOfNum = i + form.count
                for cur in currenciesSorted {
                    if endOfNum + cur.count <= n {
                        let curCand = String(chars[endOfNum..<(endOfNum + cur.count)])
                        if curCand == cur,
                           let val = SpecialCardinal.dashPairs[key] {
                            let leadOut = lead.isEmpty ? "1"
                                : (digitMap[lead.first!].map(String.init) ?? "")
                            let prefix = currencyPrefixFor(
                                cur, hasDecimal: false, hasRange: true)
                            out.append(Candidate(
                                startIdx: i,
                                endIdx: endOfNum + cur.count,
                                output: "\(prefix)\(leadOut)\(val)",
                                weight: TaggerWeight.money,
                                source: "money_dash"
                            ))
                        }
                    }
                }
            }
        }
        return out
    }

    /// Per-currency: pick symbol vs code based on context, mirroring
    /// WeText empirical behavior.
    private static func currencyPrefixFor(_ currency: String,
                                          hasDecimal: Bool,
                                          hasRange: Bool) -> String {
        let preferSymbol = hasDecimal || hasRange
            || symbolOnlyForInteger.contains(currency)
        if preferSymbol {
            return symbolPrefix[currency] ?? codePrefix[currency] ?? ""
        }
        return codePrefix[currency] ?? symbolPrefix[currency] ?? ""
    }

    static let tildeKeysSorted: [String] = SpecialCardinal.tildePairs.keys
        .sorted { $0.count > $1.count }

    /// Return all (form-string, lead-char, dash-key) matches at pos.
    /// form-string = the part of the input consumed by the dash form.
    private static func dashFormsAt(chars: [Character], pos: Int) -> [(String, String, String)] {
        var results: [(String, String, String)] = []
        let n = chars.count
        let dashPairs2 = SpecialCardinal.dashPairs.keys.filter { $0.count == 2 }
        let dashPairs3 = SpecialCardinal.dashPairs.keys.filter { $0.count == 3 }
        let leadChars: Set<Character> = ["一","二","三","四","五","六","七","八","九","两"]

        // 十 + 2-char pair
        if pos < n, chars[pos] == "十" {
            for key in dashPairs2 {
                let endIdx = pos + 1 + key.count
                if endIdx <= n,
                   String(chars[(pos + 1)..<endIdx]) == key {
                    results.append(("十\(key)", "", key))
                }
            }
        }
        // digit + 十 + 2-char pair
        if pos + 1 < n, leadChars.contains(chars[pos]), chars[pos + 1] == "十" {
            let leadStr = String(chars[pos])
            for key in dashPairs2 {
                let endIdx = pos + 2 + key.count
                if endIdx <= n,
                   String(chars[(pos + 2)..<endIdx]) == key {
                    results.append(("\(leadStr)十\(key)", leadStr, key))
                }
            }
        }
        // digit + 百 + 3-char pair
        if pos + 1 < n, leadChars.contains(chars[pos]), chars[pos + 1] == "百" {
            let leadStr = String(chars[pos])
            for key in dashPairs3 {
                let endIdx = pos + 2 + key.count
                if endIdx <= n,
                   String(chars[(pos + 2)..<endIdx]) == key {
                    results.append(("\(leadStr)百\(key)", leadStr, key))
                }
            }
        }
        return results
    }

    /// Match <cnCard>+元<cnDigit>(毛|角)[<cnDigit>分].
    /// Returns (endIdx, output).
    private static func matchYuanJiaoFen(chars: [Character],
                                         start: Int) -> (Int, String)? {
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        var j = start
        while j < n && cnCardSet.contains(chars[j]) { j += 1 }
        guard j > start, j < n, chars[j] == "元" else { return nil }
        let intStr = String(chars[start..<j])
        guard let intVal = Cardinal.parseToInt(intStr) else { return nil }
        var k = j + 1
        guard k < n, let jiao = digitMap[chars[k]] else { return nil }
        k += 1
        guard k < n, chars[k] == "毛" || chars[k] == "角" else { return nil }
        k += 1
        // Optional fen
        if k + 1 < n, let fen = digitMap[chars[k]], chars[k + 1] == "分" {
            return (k + 2, "¥\(intVal).\(jiao)\(fen)")
        }
        return (k, "¥\(intVal).\(jiao)")
    }
}

// MARK: - Math tagger

extension MathNormalize {

    /// Emit candidates per WeText math.py: number + (operator + number)+
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)

        for i in 0..<n {
            // Optional sign
            var signLen = 0
            var signOut = ""
            if i + 1 < n {
                let two = String(chars[i...(i + 1)])
                if let s = Cardinal.signMap[two] { signLen = 2; signOut = s }
            }
            if signLen == 0, let s = Cardinal.signMap[String(chars[i])] {
                signLen = 1; signOut = s
            }
            var cursor = i + signLen

            // First number
            let firstStart = cursor
            while cursor < n && cnCardSet.contains(chars[cursor]) { cursor += 1 }
            if cursor == firstStart { continue }
            // Find longest valid number prefix
            var firstEnd = cursor
            while firstEnd > firstStart {
                let cand = String(chars[firstStart..<firstEnd])
                if Cardinal.parseToInt(cand) != nil { break }
                firstEnd -= 1
            }
            guard firstEnd > firstStart,
                  let firstVal = Cardinal.parseToInt(String(chars[firstStart..<firstEnd]))
            else { continue }

            var output = "\(signOut)\(firstVal)"
            cursor = firstEnd

            // (operator + number)+ — must have at least one
            var pairCount = 0
            while cursor < n {
                // Try op at cursor (longest first)
                var opMatched: (op: String, len: Int)?
                for opLen in [2, 1] {
                    if cursor + opLen <= n {
                        let opCand = String(chars[cursor..<(cursor + opLen)])
                        if let op = operatorMap[opCand] {
                            opMatched = (op, opLen)
                            break
                        }
                    }
                }
                guard let opM = opMatched else { break }
                let nextStart = cursor + opM.len
                // Optional sign on next number
                var sLen = 0
                var sOut = ""
                if nextStart + 1 < n,
                   let s = Cardinal.signMap[String(chars[nextStart...(nextStart + 1)])] {
                    sLen = 2; sOut = s
                }
                if sLen == 0, nextStart < n,
                   let s = Cardinal.signMap[String(chars[nextStart])] {
                    sLen = 1; sOut = s
                }
                let numStart = nextStart + sLen
                var numEnd = numStart
                while numEnd < n && cnCardSet.contains(chars[numEnd]) { numEnd += 1 }
                // Backtrack to longest valid number
                while numEnd > numStart {
                    if Cardinal.parseToInt(String(chars[numStart..<numEnd])) != nil { break }
                    numEnd -= 1
                }
                guard numEnd > numStart,
                      let nVal = Cardinal.parseToInt(String(chars[numStart..<numEnd]))
                else { break }
                output += "\(opM.op)\(sOut)\(nVal)"
                cursor = numEnd
                pairCount += 1
            }

            if pairCount > 0 {
                out.append(Candidate(
                    startIdx: i,
                    endIdx: cursor,
                    output: output,
                    weight: TaggerWeight.math,
                    source: "math"
                ))
            }
        }
        return out
    }
}

// MARK: - LicensePlate tagger

extension LicensePlate {

    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let provinceSet = Set(provinceChars)

        for i in 0..<n {
            guard provinceSet.contains(chars[i]) else { continue }
            // Next char must be alpha
            guard i + 1 < n, chars[i + 1].isLetter,
                  chars[i + 1].isASCII else { continue }
            // Then 5-6 chars of (alpha | digit | cn-digit)
            var body = ""
            var bodyEnd = i + 2
            while bodyEnd < n && body.count < 6 {
                let ch = chars[bodyEnd]
                if let d = digitMap[ch] {
                    body.append(d)
                    bodyEnd += 1
                } else if ch.isASCII, ch.isLetter || ch.isNumber {
                    body.append(ch)
                    bodyEnd += 1
                } else { break }
            }
            if body.count >= 5 && body.count <= 6 {
                let alpha = String(chars[i + 1])
                let prov = String(chars[i])
                out.append(Candidate(
                    startIdx: i,
                    endIdx: bodyEnd,
                    output: "\(prov)\(alpha)\(body)",
                    weight: TaggerWeight.licensePlate,
                    source: "license_plate"
                ))
            }
        }
        return out
    }
}

// MARK: - Electronic tagger

extension Electronic {

    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        // "w w w 点 X 点 Y" pattern — server and TLD are letter runs.
        // Pattern minimally: w SP w SP w SP 点 SP <server> SP 点 SP <tld>
        // where server/tld are sequences of single alpha chars separated by spaces
        // (or contiguous letter token).
        for i in 0..<n {
            // Match "w w w 点 "
            guard i + 7 <= n else { continue }
            let head = String(chars[i..<(i + 7)])
            guard head == "w w w 点" else { continue }
            // After head we have a space + server + space + 点 + space + tld
            var cursor = i + 7
            if cursor < n && chars[cursor] == " " { cursor += 1 }
            // Server: alpha chars and spaces until next " 点 "
            let serverStart = cursor
            while cursor < n {
                if cursor + 3 <= n && String(chars[cursor..<(cursor + 3)]) == " 点 " {
                    break
                }
                let ch = chars[cursor]
                if !(ch.isASCII && (ch.isLetter || ch == " ")) { break }
                cursor += 1
            }
            guard cursor > serverStart,
                  cursor + 3 <= n,
                  String(chars[cursor..<(cursor + 3)]) == " 点 "
            else { continue }
            let serverRaw = String(chars[serverStart..<cursor])
            cursor += 3
            // TLD: alpha chars and spaces until non-alpha
            let tldStart = cursor
            while cursor < n {
                let ch = chars[cursor]
                if !(ch.isASCII && (ch.isLetter || ch == " ")) { break }
                cursor += 1
            }
            guard cursor > tldStart else { continue }
            let tldRaw = String(chars[tldStart..<cursor])
            let server = serverRaw.replacingOccurrences(of: " ", with: "")
            let tld = tldRaw.replacingOccurrences(of: " ", with: "")
            out.append(Candidate(
                startIdx: i,
                endIdx: cursor,
                output: "www.\(server).\(tld)",
                weight: TaggerWeight.electronic,
                source: "electronic"
            ))
        }
        return out
    }
}

// MARK: - SpecialCardinal helpers

extension SpecialCardinal {

    /// Return all matching dash forms at position `pos`. Each entry:
    /// (form-char-length, lead-string, dash-key).
    /// `lead` is empty for 十-prefix forms.
    static func dashFormsAtPos(chars: [Character], pos: Int) -> [(Int, String, String)] {
        var results: [(Int, String, String)] = []
        let n = chars.count
        let leadChars: Set<Character> = ["一","二","三","四","五","六","七","八","九","两"]
        let dashKeys2 = dashPairs.keys.filter { $0.count == 2 }
        let dashKeys3 = dashPairs.keys.filter { $0.count == 3 }

        // 十 + 2-char pair
        if pos < n, chars[pos] == "十" {
            for key in dashKeys2 {
                let kEnd = pos + 1 + key.count
                if kEnd <= n,
                   String(chars[(pos + 1)..<kEnd]) == key {
                    results.append((1 + key.count, "", key))
                }
            }
        }
        // digit + 十 + 2-char pair
        if pos + 1 < n, leadChars.contains(chars[pos]), chars[pos + 1] == "十" {
            let leadStr = String(chars[pos])
            for key in dashKeys2 {
                let kEnd = pos + 2 + key.count
                if kEnd <= n,
                   String(chars[(pos + 2)..<kEnd]) == key {
                    results.append((2 + key.count, leadStr, key))
                }
            }
        }
        // digit + 百 + 3-char pair
        if pos + 1 < n, leadChars.contains(chars[pos]), chars[pos + 1] == "百" {
            let leadStr = String(chars[pos])
            for key in dashKeys3 {
                let kEnd = pos + 2 + key.count
                if kEnd <= n,
                   String(chars[(pos + 2)..<kEnd]) == key {
                    results.append((2 + key.count, leadStr, key))
                }
            }
        }
        return results
    }
}

// MARK: - SpecialCardinal tagger

extension SpecialCardinal {

    /// special_tilde: key + optional 万/亿 — "三五百"→"300~500", "三四万"→"3~4万".
    /// special_dash: 十+pair / digit+十+pair / digit+百+3-pair / digit+万+digit+digit.
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        let leadChars: Set<Character> = ["一","二","三","四","五","六","七","八","九","两"]

        // tilde keys sorted longest-first
        let tildeKeys = tildePairs.keys.sorted { $0.count > $1.count }
        let dashKeys2 = dashPairs.keys.filter { $0.count == 2 }.sorted()
        let dashKeys3 = dashPairs.keys.filter { $0.count == 3 }.sorted()

        for i in 0..<n {
            // Boundary check: NOT preceded by cn-cardinal
            if i > 0 && cnCardSet.contains(chars[i - 1]) { continue }

            // 1. tilde: (key)(万/亿)?
            for key in tildeKeys {
                let kEnd = i + key.count
                guard kEnd <= n,
                      String(chars[i..<kEnd]) == key,
                      let val = tildePairs[key] else { continue }
                // No following cn-card unless 万/亿 suffix
                if kEnd < n {
                    let next = chars[kEnd]
                    if next == "万" || next == "亿" || next == "萬" || next == "億" {
                        out.append(Candidate(
                            startIdx: i, endIdx: kEnd + 1,
                            output: "\(val)\(next)",
                            weight: TaggerWeight.specialCardinal,
                            source: "special_tilde"
                        ))
                        continue
                    }
                    if cnCardSet.contains(next) { continue }
                }
                out.append(Candidate(
                    startIdx: i, endIdx: kEnd,
                    output: val,
                    weight: TaggerWeight.specialCardinal,
                    source: "special_tilde"
                ))
            }

            // 2. dash 十 + 2-char pair (+ optional 万/亿)
            if i < n, chars[i] == "十" {
                for key in dashKeys2 {
                    let kEnd = i + 1 + key.count
                    guard kEnd <= n,
                          String(chars[(i + 1)..<kEnd]) == key,
                          let val = dashPairs[key] else { continue }
                    var endIdx = kEnd
                    var suffix = ""
                    if endIdx < n {
                        let next = chars[endIdx]
                        if next == "万" || next == "亿" || next == "萬" || next == "億" {
                            suffix = String(next); endIdx += 1
                        } else if cnCardSet.contains(next) { continue }
                    }
                    out.append(Candidate(
                        startIdx: i, endIdx: endIdx,
                        output: "1\(val)\(suffix)",
                        weight: TaggerWeight.specialCardinal,
                        source: "special_dash_shi"
                    ))
                }
            }

            // 3. dash digit + 十 + 2-pair
            if i + 1 < n, leadChars.contains(chars[i]), chars[i + 1] == "十" {
                guard let lead = digitMap[chars[i]] else { continue }
                for key in dashKeys2 {
                    let kEnd = i + 2 + key.count
                    guard kEnd <= n,
                          String(chars[(i + 2)..<kEnd]) == key,
                          let val = dashPairs[key] else { continue }
                    var endIdx = kEnd
                    var suffix = ""
                    if endIdx < n {
                        let next = chars[endIdx]
                        if next == "万" || next == "亿" || next == "萬" || next == "億" {
                            suffix = String(next); endIdx += 1
                        } else if cnCardSet.contains(next) { continue }
                    }
                    out.append(Candidate(
                        startIdx: i, endIdx: endIdx,
                        output: "\(lead)\(val)\(suffix)",
                        weight: TaggerWeight.specialCardinal,
                        source: "special_dash_digit_shi"
                    ))
                }
            }

            // 4. dash digit + 百 + 3-pair
            if i + 1 < n, leadChars.contains(chars[i]), chars[i + 1] == "百" {
                guard let lead = digitMap[chars[i]] else { continue }
                for key in dashKeys3 {
                    let kEnd = i + 2 + key.count
                    guard kEnd <= n,
                          String(chars[(i + 2)..<kEnd]) == key,
                          let val = dashPairs[key] else { continue }
                    var endIdx = kEnd
                    var suffix = ""
                    if endIdx < n {
                        let next = chars[endIdx]
                        if next == "万" || next == "亿" || next == "萬" || next == "億" {
                            suffix = String(next); endIdx += 1
                        } else if cnCardSet.contains(next) { continue }
                    }
                    out.append(Candidate(
                        startIdx: i, endIdx: endIdx,
                        output: "\(lead)\(val)\(suffix)",
                        weight: TaggerWeight.specialCardinal,
                        source: "special_dash_digit_bai"
                    ))
                }
            }

            // 5. dash digit + 万 + digit + digit
            if i + 3 < n, leadChars.contains(chars[i]),
               chars[i + 1] == "万",
               leadChars.contains(chars[i + 2]),
               leadChars.contains(chars[i + 3]) {
                if let lead = digitMap[chars[i]],
                   let d2 = digitMap[chars[i + 2]],
                   let d3 = digitMap[chars[i + 3]] {
                    if i + 4 >= n || !cnCardSet.contains(chars[i + 4]) {
                        out.append(Candidate(
                            startIdx: i, endIdx: i + 4,
                            output: "\(lead)\(d2)000-\(d3)000",
                            weight: TaggerWeight.specialCardinal,
                            source: "special_dash_wan"
                        ))
                    }
                }
            }
        }
        return out
    }
}

// MARK: - Measure tagger

extension Measure {

    /// Emit candidates per WeText measure.py:
    ///   measure = number + (to + number).ques + units
    ///   tagger |= delete("每") + units + measure   (前置每)
    ///   measure_sp = digit + (百|千|万) + addzero + digit + unit_sp_case1
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        let cnDigitSet = Set(cnDigitClass)
        let units = unitsSortedLongestFirst

        for i in 0..<n {
            // Boundary: not preceded by cn-cardinal
            let lookbehindOK = (i == 0) || !cnCardSet.contains(chars[i - 1])

            // ─── Standard: (number)(unit) and (number)到(number)(unit)
            if lookbehindOK {
                // Find cn-card run [i..j)
                var j = i
                while j < n && cnCardSet.contains(chars[j]) { j += 1 }
                if j > i {
                    // Iterate num-span end positions from SHORTEST to
                    // longest. The shorter num leaves more chars for a
                    // longer unit prefix — emitted first so the lattice
                    // picks longer-unit candidates on tie-cost (mirrors
                    // WeText FST's `add_weight(units_en, -1.0)` bonus
                    // for multi-char unit names).
                    for numEnd in (i + 1)...j {
                        let numStr = String(chars[i..<numEnd])
                        emitMeasureCandidates(
                            chars: chars, n: n,
                            startIdx: i, numEnd: numEnd, numStr: numStr,
                            units: units, config: config, out: &out
                        )
                        // Decimal: numStr + 点 + cnDigits + unit
                        if numEnd < n && (chars[numEnd] == "点" || chars[numEnd] == "點") {
                            var k = numEnd + 1
                            while k < n && cnDigitSet.contains(chars[k]) { k += 1 }
                            if k > numEnd + 1 {
                                let fracStr = String(chars[(numEnd + 1)..<k])
                                let fracDigits = fracStr.compactMap { digitMap[$0] }
                                if fracDigits.count == fracStr.count,
                                   let intV = Cardinal.parseToInt(numStr) {
                                    let valStr = "\(intV).\(String(fracDigits))"
                                    emitWithUnit(
                                        chars: chars, n: n,
                                        startIdx: i, valueEnd: k, valueStr: valStr,
                                        units: units, out: &out, source: "measure_decimal"
                                    )
                                }
                            }
                        }
                        // Range: numStr + 到 + numStr2 + unit
                        if numEnd < n && chars[numEnd] == "到" {
                            let rStart = numEnd + 1
                            var k = rStart
                            while k < n && cnCardSet.contains(chars[k]) { k += 1 }
                            // Iterate second num span SHORTEST first
                            // so longer unit prefix wins on tie cost.
                            if k > rStart {
                                for kEnd in (rStart + 1)...k {
                                    let n2Str = String(chars[rStart..<kEnd])
                                    if let v1 = Cardinal.parseToInt(numStr),
                                       let v2 = Cardinal.parseToInt(n2Str) {
                                        let valStr = "\(v1)~\(v2)"
                                        emitWithUnit(
                                            chars: chars, n: n,
                                            startIdx: i, valueEnd: kEnd, valueStr: valStr,
                                            units: units, out: &out, source: "measure_range"
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─── 每X前置: 每 + unit_denom + num + (到 + num)? + unit_numer
            if i < n && chars[i] == "每" {
                for denomUnit in units {
                    let dStart = i + 1
                    let dEnd = dStart + denomUnit.count
                    guard dEnd <= n,
                          String(chars[dStart..<dEnd]) == denomUnit else { continue }
                    guard let denomEN = resolveUnit(denomUnit) else { continue }

                    // Find max cn-card run
                    var j = dEnd
                    while j < n && cnCardSet.contains(chars[j]) { j += 1 }
                    if j == dEnd { continue }

                    // Iterate num span length SHORTEST first
                    for numEnd in (dEnd + 1)...j {
                        let firstNumStr = String(chars[dEnd..<numEnd])
                        guard let v1 = Cardinal.parseToInt(firstNumStr) else { continue }

                        // Optional 到 + second num
                        var ranges: [(end: Int, valueStr: String)] = [
                            (numEnd, "\(v1)")
                        ]
                        if numEnd < n && chars[numEnd] == "到" {
                            let rStart = numEnd + 1
                            var k = rStart
                            while k < n && cnCardSet.contains(chars[k]) { k += 1 }
                            if k > rStart {
                                for kEnd in (rStart + 1)...k {
                                    let n2Str = String(chars[rStart..<kEnd])
                                    if let v2 = Cardinal.parseToInt(n2Str) {
                                        ranges.append((kEnd, "\(v1)~\(v2)"))
                                    }
                                }
                            }
                        }

                        // For each range endpoint, try numerator unit
                        for (rangeEnd, valueStr) in ranges {
                            for numerUnit in units {
                                let nuEnd = rangeEnd + numerUnit.count
                                guard nuEnd <= n,
                                      String(chars[rangeEnd..<nuEnd]) == numerUnit
                                else { continue }
                                guard let numerEN = resolveUnit(numerUnit) else { continue }
                                out.append(Candidate(
                                    startIdx: i, endIdx: nuEnd,
                                    output: "\(valueStr)\(numerEN)/\(denomEN)",
                                    weight: TaggerWeight.measure,
                                    source: "measure_per_prefix"
                                ))
                            }
                        }
                    }
                }
            }

            // ─── Tilde key + (万|亿)? + unit → "X~Y[万/亿]unit"
            // Try "unit subsumes 万/亿" path FIRST (e.g. 万伏特 → Wv),
            // then "万/亿 kept as plain suffix" path (e.g. 万吨 → 万吨).
            // Earlier-emitted candidate wins on tie cost.
            if lookbehindOK {
                for tildeKey in SpecialCardinal.tildePairs.keys.sorted(by: { $0.count > $1.count }) {
                    let tEnd = i + tildeKey.count
                    guard tEnd <= n,
                          String(chars[i..<tEnd]) == tildeKey,
                          let tildeVal = SpecialCardinal.tildePairs[tildeKey] else { continue }
                    // Path A: unit claims 万/亿 prefix (multi-char unit)
                    for unit in units where unit.count >= 2 {
                        let uEnd = tEnd + unit.count
                        guard uEnd <= n,
                              String(chars[tEnd..<uEnd]) == unit,
                              let unitOut = resolveUnit(unit) else { continue }
                        out.append(Candidate(
                            startIdx: i, endIdx: uEnd,
                            output: "\(tildeVal)\(unitOut)",
                            weight: TaggerWeight.measure,
                            source: "measure_tilde_unit"
                        ))
                    }
                    // Path B: 万/亿 stays as plain Chinese suffix, then unit
                    if tEnd < n {
                        let c = chars[tEnd]
                        if c == "万" || c == "亿" || c == "萬" || c == "億" {
                            for unit in units {
                                let uEnd = tEnd + 1 + unit.count
                                guard uEnd <= n,
                                      String(chars[(tEnd + 1)..<uEnd]) == unit,
                                      let unitOut = resolveUnit(unit) else { continue }
                                out.append(Candidate(
                                    startIdx: i, endIdx: uEnd,
                                    output: "\(tildeVal)\(c)\(unitOut)",
                                    weight: TaggerWeight.measure,
                                    source: "measure_tilde_suffix_unit"
                                ))
                            }
                        }
                    }
                    // Path C: no suffix, just (tilde)(unit) — single-char units etc.
                    for unit in units where unit.count == 1 {
                        let uEnd = tEnd + unit.count
                        guard uEnd <= n,
                              String(chars[tEnd..<uEnd]) == unit,
                              let unitOut = resolveUnit(unit) else { continue }
                        out.append(Candidate(
                            startIdx: i, endIdx: uEnd,
                            output: "\(tildeVal)\(unitOut)",
                            weight: TaggerWeight.measure,
                            source: "measure_tilde_unit"
                        ))
                    }
                }
            }

            // ─── Dash forms + unit
            if lookbehindOK {
                let dashForms = SpecialCardinal.dashFormsAtPos(chars: chars, pos: i)
                for (formLen, lead, key) in dashForms {
                    guard let dashVal = SpecialCardinal.dashPairs[key] else { continue }
                    let leadStr: String
                    if lead.isEmpty {
                        leadStr = "1"  // 十-prefix case
                    } else if let l = digitMap[lead.first!] {
                        leadStr = String(l)
                    } else { continue }
                    let formEnd = i + formLen
                    for unit in units {
                        let uEnd = formEnd + unit.count
                        guard uEnd <= n,
                              String(chars[formEnd..<uEnd]) == unit,
                              let unitOut = resolveUnit(unit) else { continue }
                        out.append(Candidate(
                            startIdx: i, endIdx: uEnd,
                            output: "\(leadStr)\(dashVal)\(unitOut)",
                            weight: TaggerWeight.measure,
                            source: "measure_dash_unit"
                        ))
                    }
                }
            }

            // ─── unit_sp_case1: digit + (百|千|万) + digit + 量词
            if lookbehindOK, i + 3 < n {
                let d1 = chars[i]
                let mag = chars[i + 1]
                let d2 = chars[i + 2]
                guard "一二三四五六七八九".contains(d1),
                      "百千万".contains(mag),
                      "一二三四五六七八九".contains(d2),
                      let d1Arabic = digitMap[d1],
                      let d2Arabic = digitMap[d2] else { continue }
                let unitSpStart = i + 3
                for spUnit in unitSpCase1 {
                    let usEnd = unitSpStart + spUnit.count
                    guard usEnd <= n,
                          String(chars[unitSpStart..<usEnd]) == spUnit else { continue }
                    let zeros: String
                    switch mag {
                    case "百": zeros = "00"
                    case "千": zeros = "000"
                    case "万": zeros = "0000"
                    default: zeros = ""
                    }
                    out.append(Candidate(
                        startIdx: i, endIdx: usEnd,
                        output: "\(d1Arabic)\(zeros)\(d2Arabic)\(spUnit)",
                        weight: TaggerWeight.measure,
                        source: "measure_sp_case1"
                    ))
                    break
                }
            }
        }
        return out
    }

    /// unit_sp_case1 list (WeText measure.py:78).
    static let unitSpCase1: [String] = [
        "年", "月", "个月", "周", "天", "位", "次", "个", "顿",
    ]

    /// Emit measure candidates for cardinal number + unit.
    /// For multi-segment numbers (一亿X / X兆Y), prefer
    /// `Cardinal.parse` output which keeps 亿/万 as text.
    private static func emitMeasureCandidates(
        chars: [Character], n: Int,
        startIdx: Int, numEnd: Int, numStr: String,
        units: [String], config: ChineseITNConfig,
        out: inout [Candidate]
    ) {
        // Single-digit + unit guard under !enable_0_to_9
        let isSingleDigit = numStr.count == 1 &&
            digitChars.contains(numStr.first!)
        if !config.enable0To9 && isSingleDigit { return }

        // Try Cardinal.parse first (handles 亿/万 segment-keeping).
        // For single-digit, parse returns Chinese; use parseToInt instead.
        var valueStr: String?
        if isSingleDigit {
            if let d = digitMap[numStr.first!] {
                valueStr = String(d)
            }
        } else if let parsed = Cardinal.parse(numStr) {
            valueStr = parsed
        } else if let intVal = Cardinal.parseToInt(numStr) {
            valueStr = "\(intVal)"
        }
        guard let v = valueStr else { return }
        emitWithUnit(
            chars: chars, n: n,
            startIdx: startIdx, valueEnd: numEnd, valueStr: v,
            units: units, out: &out, source: "measure_cardinal"
        )
    }

    private static func emitWithUnit(
        chars: [Character], n: Int,
        startIdx: Int, valueEnd: Int, valueStr: String,
        units: [String], out: inout [Candidate], source: String
    ) {
        for unit in units {
            let uEnd = valueEnd + unit.count
            guard uEnd <= n,
                  String(chars[valueEnd..<uEnd]) == unit else { continue }
            guard let unitOut = resolveUnit(unit) else { continue }
            out.append(Candidate(
                startIdx: startIdx, endIdx: uEnd,
                output: "\(valueStr)\(unitOut)",
                weight: TaggerWeight.measure,
                source: source
            ))
            // Note: longest-first iteration; emit first match per unit then continue
            // to allow shorter alternatives too (lattice picks).
        }
    }
}

// MARK: - Time tagger

extension TimeNormalize {

    /// Emit time candidates: (noon)? + hour + minute + (分)? + second?.
    /// minute is required per WeText time.py:35. No cn-cardinal
    /// lookbehind — the lattice handles that via global cost.
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let s = String(chars)

        // Iterate each starting position
        for i in 0..<n {
            // Optional noon prefix
            var noonLen = 0
            var noonOut = ""
            for noonKey in noonMapKeys {
                if i + noonKey.count <= n {
                    let candidate = String(chars[i..<(i + noonKey.count)])
                    if candidate == noonKey {
                        noonLen = noonKey.count
                        noonOut = noonMapLocal[noonKey] ?? ""
                        break
                    }
                }
            }
            let hourStart = i + noonLen

            // Hour: try longest first
            var hourMatch: (key: String, len: Int)?
            for hourKey in hourMapKeys {
                if hourStart + hourKey.count <= n {
                    let candidate = String(chars[hourStart..<(hourStart + hourKey.count)])
                    if candidate == hourKey {
                        hourMatch = (hourKey, hourKey.count)
                        break
                    }
                }
            }
            guard let hourM = hourMatch else { continue }
            let minuteStart = hourStart + hourM.len

            // Minute: try longest first
            var minuteMatch: (key: String, len: Int)?
            for minuteKey in minuteMapKeys {
                if minuteStart + minuteKey.count <= n {
                    let candidate = String(chars[minuteStart..<(minuteStart + minuteKey.count)])
                    if candidate == minuteKey {
                        minuteMatch = (minuteKey, minuteKey.count)
                        break
                    }
                }
            }
            guard let minuteM = minuteMatch else { continue }
            var endIdx = minuteStart + minuteM.len

            // Optional 分
            if endIdx < n && chars[endIdx] == "分" {
                endIdx += 1
            }

            // Optional second
            var secondOut = ""
            for secondKey in secondMapKeys {
                if endIdx + secondKey.count <= n {
                    let candidate = String(chars[endIdx..<(endIdx + secondKey.count)])
                    if candidate == secondKey {
                        secondOut = secondMap[secondKey] ?? ""
                        endIdx += secondKey.count
                        break
                    }
                }
            }

            guard let hOut = hourMap[hourM.key],
                  let mOut = minuteMap[minuteM.key] else { continue }
            var output = "\(hOut):\(mOut)"
            if !secondOut.isEmpty { output += ":\(secondOut)" }
            output += noonOut

            out.append(Candidate(
                startIdx: i,
                endIdx: endIdx,
                output: output,
                weight: TaggerWeight.time,
                source: "time"
            ))
            _ = s  // silence unused warning if any
        }
        return out
    }

    static let hourMapKeys: [String] = hourMap.keys.sorted { $0.count > $1.count }
    static let minuteMapKeys: [String] = minuteMap.keys.sorted { $0.count > $1.count }
    static let secondMapKeys: [String] = secondMap.keys.filter { !$0.isEmpty }
        .sorted { $0.count > $1.count }
    static let noonMapKeys: [String] = noonMap.keys.sorted { $0.count > $1.count }
}

// MARK: - Cardinal tagger

extension Cardinal {

    /// Emit candidate edges for cardinal runs in `chars`. A "cardinal
    /// run" is a maximal sequence of cn-cardinal-class chars (digits +
    /// 十/百/千/万/亿) optionally preceded by a sign marker (正/负/etc).
    /// For each run, try to parse it into an Arabic value; also try
    /// shorter prefixes so the lattice can prefer split parses when
    /// they yield lower total cost (e.g. "三百九十九三" → 399 + 3).
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)

        var i = 0
        while i < n {
            // Optional sign prefix at position i
            var signLen = 0
            var signOut = ""
            if i + 1 < n {
                let two = String(chars[i...i+1])
                if let s = signMap[two] { signLen = 2; signOut = s }
            }
            if signLen == 0, let s = signMap[String(chars[i])] {
                signLen = 1; signOut = s
            }
            let runStart = i + signLen

            // Find end of cn-cardinal run starting at runStart
            var j = runStart
            while j < n && cnCardSet.contains(chars[j]) { j += 1 }
            if j == runStart {
                i += 1  // no cardinal run here
                continue
            }

            // Try every prefix length from longest to shortest, emit
            // a candidate for each that parses. The lattice picks.
            for endIdx in stride(from: j, through: runStart + 1, by: -1) {
                let run = String(chars[runStart..<endIdx])
                if let parsed = parseOne(run, config: config) {
                    out.append(Candidate(
                        startIdx: i,
                        endIdx: endIdx,
                        output: signOut + parsed,
                        weight: TaggerWeight.cardinal,
                        source: "cardinal"
                    ))
                }
            }

            // Multi-cardinal split (WeText `cardinal + (insert(" ") +
            // cardinal).star`). For a pure-digit run that can be split
            // into multiple valid-length cardinals (3/4/5/11/18 each),
            // emit a single combined candidate with space separator.
            // Cost matches single-cardinal weight so it beats the
            // multi-edge path on cost.
            if j > runStart,
               String(chars[runStart..<j]).allSatisfy({ digitChars.contains($0) }) {
                let runChars = Array(chars[runStart..<j])
                if let joined = splitIntoValidCardinals(runChars) {
                    out.append(Candidate(
                        startIdx: i,
                        endIdx: j,
                        output: signOut + joined,
                        weight: TaggerWeight.cardinal,
                        source: "cardinal_multi"
                    ))
                }
            }

            // ID-card form: 17 digit chars + "X"/"x" suffix. WeText
            // cardinal.py line 159: `(digits**17 + idcard_last_char)`.
            if j == runStart + 17,
               j < n,
               (chars[j] == "X" || chars[j] == "x"),
               String(chars[runStart..<j]).allSatisfy({ digitChars.contains($0) }) {
                let arabic = String(chars[runStart..<j].map { digitMap[$0]! })
                out.append(Candidate(
                    startIdx: i,
                    endIdx: j + 1,
                    output: "\(signOut)\(arabic)\(chars[j])",
                    weight: TaggerWeight.cardinal,
                    source: "cardinal_idcard"
                ))
            }

            i = max(i + 1, runStart + 1)
        }
        return out
    }

    /// Split a pure-digit run into a sequence of valid-length cardinals
    /// (each length in {3,4,5,11,18}). Returns the joined Arabic output
    /// with " " between segments, or nil if no clean split exists.
    private static func splitIntoValidCardinals(_ chars: [Character]) -> String? {
        let allowed: [Int] = [11, 18, 5, 4, 3]
        // DP: dp[i] = best (fewest-segments, output) covering chars[0..<i].
        var dp: [String?] = Array(repeating: nil, count: chars.count + 1)
        dp[0] = ""
        for i in 1...chars.count {
            for len in allowed where len <= i {
                if let prev = dp[i - len] {
                    let segChars = chars[(i - len)..<i]
                    let arabic = String(segChars.map { digitMap[$0]! })
                    let joined = prev.isEmpty ? arabic : prev + " " + arabic
                    if dp[i] == nil { dp[i] = joined }
                }
            }
        }
        guard let result = dp[chars.count], !result.isEmpty,
              result.contains(" ") else { return nil }
        return result
    }

    /// Parse a single cardinal run respecting the config. Returns
    /// arabic output string, or nil if not parseable as a single
    /// cardinal.
    private static func parseOne(_ s: String,
                                 config: ChineseITNConfig) -> String? {
        if s.count == 1, let ch = s.first, digitChars.contains(ch) {
            if config.enable0To9, let d = digitMap[ch] {
                return String(d)
            }
            return nil  // single digit not allowed
        }
        return parse(s)
    }
}

// MARK: - Decimal tagger

extension Decimal {

    /// Emit decimal candidates: "X点Y" where X is a cardinal expression
    /// and Y is digit-by-digit chars. Also emits IP-form (X点Y点Z...).
    static func tag(_ chars: [Character],
                    config: ChineseITNConfig) -> [Candidate] {
        var out: [Candidate] = []
        let n = chars.count
        let cnCardSet = Set(cnCardinalClass)
        let cnDigitSet = Set(cnDigitClass)

        var i = 0
        while i < n {
            // Optional sign at i
            var signLen = 0
            var signOut = ""
            if let s = Cardinal.signMap[String(chars[i])] {
                signLen = 1; signOut = s
            }
            if i + 1 < n,
               let s2 = Cardinal.signMap[String(chars[i...i+1])] {
                signLen = 2; signOut = s2
            }
            let intStart = i + signLen

            // Cardinal integer part: greedy cnCard run
            var j = intStart
            while j < n && cnCardSet.contains(chars[j]) { j += 1 }
            if j == intStart || j >= n {
                i += 1; continue
            }
            if chars[j] != "点" && chars[j] != "點" {
                i += 1; continue
            }
            let dotIdx = j
            // Fractional: one or more cnDigit chars
            var k = dotIdx + 1
            while k < n && cnDigitSet.contains(chars[k]) { k += 1 }
            if k == dotIdx + 1 {
                i += 1; continue
            }

            // Build int part and try multiple prefix lengths
            let intStrFull = String(chars[intStart..<dotIdx])
            let fracStrFull = String(chars[(dotIdx + 1)..<k])

            // Standard decimal: full int + full frac
            if let intVal = parseIntFlexible(intStrFull, config: config) {
                let fracDigits = fracStrFull.compactMap { digitMap[$0] }
                if fracDigits.count == fracStrFull.count {
                    out.append(Candidate(
                        startIdx: i,
                        endIdx: k,
                        output: "\(signOut)\(intVal).\(String(fracDigits))",
                        weight: TaggerWeight.cardinal,  // decimal is part of cardinal in WeText
                        source: "decimal"
                    ))
                }
            }

            // IP form: multiple 点-separated digit segments. Only emit
            // if the original sequence has ≥2 dots at the cnDigit
            // level. We re-scan for that pattern from intStart.
            if let (ipEnd, ipOut) = tryIPForm(chars: chars,
                                              start: intStart) {
                out.append(Candidate(
                    startIdx: i,
                    endIdx: ipEnd,
                    output: "\(signOut)\(ipOut)",
                    weight: TaggerWeight.cardinal,
                    source: "ip"
                ))
            }

            i += 1
        }
        return out
    }

    /// Match `digit+ (点 digit+)+` starting at `start`. Returns
    /// (endIdx, formatted) if at least 3 dot-separated segments found.
    private static func tryIPForm(chars: [Character],
                                  start: Int) -> (Int, String)? {
        let n = chars.count
        let cnDigitSet = Set(cnDigitClass)
        var segments: [String] = []
        var cursor = start
        while cursor < n {
            let segStart = cursor
            while cursor < n && cnDigitSet.contains(chars[cursor]) {
                cursor += 1
            }
            if cursor == segStart { break }
            segments.append(String(chars[segStart..<cursor]))
            if cursor >= n || chars[cursor] != "点" { break }
            cursor += 1
        }
        guard segments.count >= 3 else { return nil }
        // Trim trailing 点 if we consumed it without a following segment.
        // Walk back: cursor sits right after last segment.
        let arabicSegs: [String] = segments.compactMap { seg in
            let digits = seg.compactMap { digitMap[$0] }
            return digits.count == seg.count ? String(digits) : nil
        }
        guard arabicSegs.count == segments.count else { return nil }
        return (cursor, arabicSegs.joined(separator: "."))
    }

    /// Parse an integer-side cardinal allowing single digits when
    /// `enable_0_to_9` is true, else only multi-char (matches WeText
    /// number / number_exclude_0_to_9 used by Decimal context).
    private static func parseIntFlexible(_ s: String,
                                         config: ChineseITNConfig) -> String? {
        if s.count == 1, let ch = s.first, digitChars.contains(ch) {
            // Decimals always allow single-digit int side (matches WeText
            // cardinal.py — number includes digits when assembled with
            // dot, even for number_exclude_0_to_9 path the dot anchor
            // implies a quantitative read).
            return digitMap[ch].map(String.init)
        }
        return Cardinal.parse(s)
    }
}
