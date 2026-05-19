// DashConnectorTests.swift
// "X杠Y" identifier / range pattern, treated symmetrically with
// "X点Y" decimal: both sides arabize, separator maps to "-" (杠) /
// "." (点). The implementation reuses the Decimal.tag scan loop with
// a separator-aware branch.
//
// Design rationale: WeText half-converts "三杠二十三 → 三杠23"
// (only the right side becomes Arabic, half-finished output);
// FunASR's coarse tokenizer happens to preserve it intact (but as a
// side-effect, not design); cn2an converts both sides but keeps "杠"
// literal ("3杠23"). We choose the cleanest symmetric form: both
// sides Arabic, separator becomes "-".

import XCTest
@testable import ChineseITN

final class DashConnectorTests: XCTestCase {

    // MARK: - True positives

    func testStandardIdentifier() {
        XCTAssertEqual(ChineseITN.normalize("三杠二十三"), "3-23")
        XCTAssertEqual(ChineseITN.normalize("版本三杠二十"), "版本3-20")
        XCTAssertEqual(ChineseITN.normalize("章节五杠三"), "章节5-3")
    }

    func testSingleDigitBothSides() {
        // Mirrors decimal "三点二三" where single-digit int side still
        // converts because of the X<sep>Y anchor.
        XCTAssertEqual(ChineseITN.normalize("一杠二"), "1-2")
        XCTAssertEqual(ChineseITN.normalize("第三章一杠二"), "第三章1-2")
    }

    func testDigitStreamRightSide() {
        // "一二" is pure-digit length 2 — not a valid standalone
        // cardinal but valid as ASR-style version "12". In X杠Y
        // context, fall back to digit-stream concatenation.
        XCTAssertEqual(ChineseITN.normalize("三杠一二"), "3-12")
        XCTAssertEqual(ChineseITN.normalize("三杠一二三"), "3-123")
    }

    func testMixedLeftRight() {
        XCTAssertEqual(ChineseITN.normalize("十杠二十三"), "10-23")
        XCTAssertEqual(ChineseITN.normalize("一百杠五"), "100-5")
    }

    func testDecimalStillWorks() {
        // Make sure adding the 杠 branch didn't break the decimal
        // (X点Y) path.
        XCTAssertEqual(ChineseITN.normalize("三点二三"), "3.23")
        XCTAssertEqual(ChineseITN.normalize("零点五"), "0.5")
        XCTAssertEqual(ChineseITN.normalize("负三点一四"), "-3.14")
    }

    // MARK: - False positives (should NOT trigger)

    func testNoCardinalPrefix() {
        // "杠" with non-cardinal LHS — keep as plain word.
        XCTAssertEqual(ChineseITN.normalize("单杠"), "单杠")
        XCTAssertEqual(ChineseITN.normalize("扁担杠两头沉"), "扁担杠两头沉")
    }

    func testNoCardinalSuffix() {
        // "X杠" with no following cardinal — no match.
        XCTAssertEqual(ChineseITN.normalize("三杠"), "三杠")
        XCTAssertEqual(ChineseITN.normalize("三杠abc"), "三杠abc")
    }

    func testIdiomNotTriggered() {
        // Whitelist idioms containing 杠 (none in current whitelist
        // but verify we don't mis-fire on adjacent contexts).
        XCTAssertEqual(ChineseITN.normalize("我吃了一杠面包"), "我吃了一杠面包")
        // "一杠" alone with non-cardinal follow → keep
    }

    func testEmbeddedInSentence() {
        let input = "请打开版本三杠二十三的设置页面"
        let expected = "请打开版本3-23的设置页面"
        XCTAssertEqual(ChineseITN.normalize(input), expected)
    }
}
