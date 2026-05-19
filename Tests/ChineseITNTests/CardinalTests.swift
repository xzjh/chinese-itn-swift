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
        XCTAssertEqual(Cardinal.parse("一一"), "11")
        XCTAssertEqual(Cardinal.parse("二零二六"), "2026")
        XCTAssertEqual(Cardinal.parse("二零零八"), "2008")
        XCTAssertEqual(Cardinal.parse("一二三"), "123")
        XCTAssertEqual(Cardinal.parse("一二三四五"), "12345")
    }

    func testParsePhoneNumberSplit() {
        // 15-char digit run = 4-prefix + 11-phone, space separator.
        XCTAssertEqual(Cardinal.parse("一二三四幺三八幺幺幺零零零零零"), "1234 13811100000")
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

    func testParseTenThousand() {
        XCTAssertEqual(Cardinal.parse("一万"), "10000")
        XCTAssertEqual(Cardinal.parse("两万"), "20000")
        XCTAssertEqual(Cardinal.parse("一万五千"), "15000")
        XCTAssertEqual(Cardinal.parse("一万一"), "11000")
        XCTAssertEqual(Cardinal.parse("一万五"), "15000")
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
