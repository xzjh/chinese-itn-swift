// CardinalTests.swift
// Unit tests for Cardinal module covering both `parse()` and
// `normalize()`. Independent of the parity fixtures.

import XCTest
@testable import ChineseITN

final class CardinalTests: XCTestCase {

    // MARK: parse() — single-expression API

    func testParseSingleDigit() {
        XCTAssertEqual(Cardinal.parse("一"), "一")     // stays Chinese
        XCTAssertEqual(Cardinal.parse("零"), "零")
        XCTAssertEqual(Cardinal.parse("九"), "九")
    }

    func testParseAlternateForms() {
        XCTAssertEqual(Cardinal.parse("幺"), "幺")     // single char stays
        XCTAssertEqual(Cardinal.parse("两"), "两")
        XCTAssertEqual(Cardinal.parse("两万"), "20000")
    }

    func testParseDigitSequence() {
        // WeText cardinal.py restricts pure-digit reads to lengths
        // {3, 4, 5, 11, 18}. Length 2 is NOT a valid standalone
        // cardinal — would be special_tilde pair instead.
        XCTAssertNil(Cardinal.parse("一一"))
        XCTAssertEqual(Cardinal.parse("二零二六"), "2026")
        XCTAssertEqual(Cardinal.parse("二零零八"), "2008")
        XCTAssertEqual(Cardinal.parse("一二三"), "123")
        XCTAssertEqual(Cardinal.parse("一二三四五"), "12345")
    }

    func testParsePhoneNumberSplit() {
        // WeText concatenates multiple valid-length cardinals via
        // `(insert(" ") + cardinal).star`. The Lattice solver in
        // ChineseITN.normalize handles the multi-cardinal split;
        // Cardinal.parse alone doesn't claim a 15-char compound run.
        XCTAssertNil(Cardinal.parse("一二三四幺三八幺幺幺零零零零零"))
        let out = ChineseITN.normalize("加一二三四幺三八幺幺幺零零零零零",
                                       config: .weTextOfficialTest)
        XCTAssertTrue(out.contains("1234"), "got: \(out)")
        XCTAssertTrue(out.contains("13811100000"), "got: \(out)")
    }

    func testParsePositional() {
        XCTAssertEqual(Cardinal.parse("十"), "10")
        XCTAssertEqual(Cardinal.parse("十一"), "11")
        XCTAssertEqual(Cardinal.parse("二十"), "20")
        XCTAssertEqual(Cardinal.parse("二十一"), "21")
        XCTAssertEqual(Cardinal.parse("九十九"), "99")
    }

    func testParseHundred() {
        XCTAssertEqual(Cardinal.parse("一百"), "100")
        XCTAssertEqual(Cardinal.parse("一百一"), "110")       // trailing → tens
        XCTAssertEqual(Cardinal.parse("一百零一"), "101")     // 零 → ones
        XCTAssertEqual(Cardinal.parse("一百二十三"), "123")
        XCTAssertEqual(Cardinal.parse("九百九十九"), "999")
    }

    func testParseThousand() {
        XCTAssertEqual(Cardinal.parse("一千"), "1000")
        XCTAssertEqual(Cardinal.parse("一千一"), "1100")
        XCTAssertEqual(Cardinal.parse("一千零一"), "1001")
        XCTAssertEqual(Cardinal.parse("一千二百三十四"), "1234")
    }

    /// Smoke test for the new lattice + tagger architecture. Uses
    /// only Cardinal + Decimal candidates plus Char fallback.
    func testLatticeSmoke() {
        let cases: [(String, ChineseITNConfig, String)] = [
            ("一万两千三百", .weTextOfficialTest, "12300"),
            ("一二三", .weTextOfficialTest, "123"),
            ("我有五十块钱", .default, "我有50块钱"),  // 50 wins via Cardinal
            ("三点一四", .default, "3.14"),
            ("幺二七点零点零点幺", .default, "127.0.0.1"),
            ("三百九十九三", .weTextOfficialTest, "3993"),
            ("两千五百万", .default, "2500万"),
            ("一", .weTextOfficialTest, "1"),  // single digit converts under official
            ("一", .default, "一"),  // single digit stays under default
        ]
        for (input, cfg, expected) in cases {
            let chars = Array(input)
            var candidates: [Candidate] = []
            candidates += Cardinal.tag(chars, config: cfg)
            candidates += Decimal.tag(chars, config: cfg)
            let actual = Lattice.bestPath(chars: chars, candidates: candidates)
            if actual != expected {
                print("DEBUG input=\(input) candidates:")
                for c in candidates {
                    print("  (\(c.startIdx),\(c.endIdx),'\(c.output)',w=\(c.weight),src=\(c.source))")
                }
            }
            XCTAssertEqual(actual, expected, "input: \(input)")
        }
    }

    func testParseTenThousand() {
        XCTAssertEqual(Cardinal.parse("一万"), "10000")
        XCTAssertEqual(Cardinal.parse("两万"), "20000")
        XCTAssertEqual(Cardinal.parse("一万五千"), "15000")
        XCTAssertEqual(Cardinal.parse("一万一"), "11000")
        XCTAssertEqual(Cardinal.parse("一万五"), "15000")
        XCTAssertEqual(Cardinal.parse("一万两千三百"), "12300")
        XCTAssertEqual(ChineseITN.normalize("一万两千三百", config: .weTextOfficialTest), "12300")
    }

    func testParseKeptTenThousandSuffix() {
        // WeText behavior: thousand/hundred + 万 keeps 万 suffix
        XCTAssertEqual(Cardinal.parse("两千五百万"), "2500万")
        XCTAssertEqual(Cardinal.parse("三百万"), "300万")
        XCTAssertEqual(Cardinal.parse("一千万"), "1000万")
    }

    func testParseInvalid() {
        XCTAssertNil(Cardinal.parse(""))
        XCTAssertNil(Cardinal.parse("百"))  // bare 百 without coefficient
        XCTAssertNil(Cardinal.parse("abc"))
    }

    // MARK: parseToInt() — for use by other modules

    func testParseToIntSingleDigit() {
        XCTAssertEqual(Cardinal.parseToInt("一"), 1)
        XCTAssertEqual(Cardinal.parseToInt("二"), 2)
        XCTAssertEqual(Cardinal.parseToInt("九"), 9)
        XCTAssertEqual(Cardinal.parseToInt("零"), 0)
    }

    func testParseToIntMulti() {
        XCTAssertEqual(Cardinal.parseToInt("十"), 10)
        XCTAssertEqual(Cardinal.parseToInt("十二"), 12)
        XCTAssertEqual(Cardinal.parseToInt("二十一"), 21)
        XCTAssertEqual(Cardinal.parseToInt("一百"), 100)
    }

    // MARK: normalize() — in-sentence scanner

    func testNormalizeKeepsSingleDigit() {
        XCTAssertEqual(Cardinal.normalize("我说一句话"), "我说一句话")
    }

    func testNormalizeConvertsInSentence() {
        XCTAssertEqual(Cardinal.normalize("我有五十块钱"), "我有50块钱")
        XCTAssertEqual(Cardinal.normalize("团队从十五人扩到四十人"),
                       "团队从15人扩到40人")
    }

    func testNormalizeKeepsNonCardinal() {
        XCTAssertEqual(Cardinal.normalize("Hello world"), "Hello world")
    }
}
