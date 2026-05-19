// ConfigFlagsTests.swift
// Validates that ChineseITNConfig flags actually affect output as
// documented. Covers both true-positive (flag changes behavior in
// the expected direction) and false-positive (flag does NOT affect
// orthogonal categories).
//
// Each expected value was verified against the WeText Python
// reference under the matching config.

import XCTest
@testable import ChineseITN

final class ConfigFlagsTests: XCTestCase {

    // MARK: - enable_million

    /// TP: --enable-million=true fully arabizes 千/百+万 prefixes
    /// while keeping 亿 as a text marker. Mirrors WeText FST
    /// cardinal.py: when enable_million=True, the ten_thousand path
    /// removes the `accep("万")` alternative.
    func testEnableMillionExpandsManSuffix() {
        var cfg = ChineseITNConfig.default
        cfg.enableMillion = true
        XCTAssertEqual(ChineseITN.normalize("两千五百万", config: cfg), "25000000")
        XCTAssertEqual(ChineseITN.normalize("一千万", config: cfg), "10000000")
        XCTAssertEqual(ChineseITN.normalize("三百万", config: cfg), "3000000")
    }

    func testEnableMillionKeepsYiAsMarker() {
        var cfg = ChineseITNConfig.default
        cfg.enableMillion = true
        // 亿 always keeps text (WeText accep("亿")).
        XCTAssertEqual(ChineseITN.normalize("三亿五千万", config: cfg), "3亿50000000")
        XCTAssertEqual(ChineseITN.normalize("一亿两千三百", config: cfg), "1亿2300")
        XCTAssertEqual(ChineseITN.normalize("十亿", config: cfg), "10亿")
    }

    /// Default (enable_million=false): 千/百+万 keeps 万 as a text
    /// readability marker.
    func testDefaultKeeps万Suffix() {
        XCTAssertEqual(ChineseITN.normalize("两千五百万"), "2500万")
        XCTAssertEqual(ChineseITN.normalize("一千万"), "1000万")
        XCTAssertEqual(ChineseITN.normalize("三亿五千万"), "3亿5000万")
    }

    /// FP: enable_million should NOT change non-万 cardinals.
    func testEnableMillionDoesNotAffectNonWanCardinals() {
        var cfg = ChineseITNConfig.default
        cfg.enableMillion = true
        let cardinals = [
            ("一百二十三", "123"),
            ("三千五百", "3500"),
            ("一万一", "11000"),
            ("两万", "20000"),
            ("九十九", "99"),
        ]
        for (input, expected) in cardinals {
            let withFlag = ChineseITN.normalize(input, config: cfg)
            let withoutFlag = ChineseITN.normalize(input)
            XCTAssertEqual(withFlag, expected, "with flag: \(input)")
            XCTAssertEqual(withoutFlag, expected, "without flag: \(input)")
        }
    }

    /// FP: enable_million should NOT affect decimals.
    func testEnableMillionDoesNotAffectDecimals() {
        var cfg = ChineseITNConfig.default
        cfg.enableMillion = true
        XCTAssertEqual(ChineseITN.normalize("三点一四", config: cfg), "3.14")
        XCTAssertEqual(ChineseITN.normalize("零点五", config: cfg), "0.5")
    }

    // MARK: - enable_standalone_number

    /// TP: --disable-standalone-number → bare cardinal expressions
    /// stay in Chinese. WeText drops the Cardinal tagger entirely
    /// from the FST union under this flag.
    func testDisableStandaloneNumberKeepsBareCardinals() {
        var cfg = ChineseITNConfig.default
        cfg.enableStandaloneNumber = false
        XCTAssertEqual(ChineseITN.normalize("两万", config: cfg), "两万")
        XCTAssertEqual(ChineseITN.normalize("三十五", config: cfg), "三十五")
        XCTAssertEqual(ChineseITN.normalize("一百二十", config: cfg), "一百二十")
        XCTAssertEqual(ChineseITN.normalize("一千万", config: cfg), "一千万")
    }

    func testDefaultConvertsBareCardinals() {
        XCTAssertEqual(ChineseITN.normalize("两万"), "20000")
        XCTAssertEqual(ChineseITN.normalize("三十五"), "35")
        XCTAssertEqual(ChineseITN.normalize("一百二十"), "120")
    }

    /// FP: disable_standalone_number must NOT break unit-bound
    /// numbers — Measure / Money / Fraction taggers emit their own
    /// candidates that internally consume cardinals.
    func testDisableStandaloneNumberDoesNotBreakUnitBoundCases() {
        var cfg = ChineseITNConfig.default
        cfg.enableStandaloneNumber = false
        // Note: under enable_0_to_9=false (default), "一千克" → "1000g"
        // (Cardinal "一千"=1000 + 克=g), not "1kg" (which would require
        // single digit "一"=1 + 千克=kg). WeText reference confirmed.
        XCTAssertEqual(ChineseITN.normalize("一千克", config: cfg), "1000g")
        XCTAssertEqual(ChineseITN.normalize("两百欧元", config: cfg), "€200")
        XCTAssertEqual(ChineseITN.normalize("百分之三十", config: cfg), "30%")
        XCTAssertEqual(ChineseITN.normalize("重达二十五千克", config: cfg), "重达25kg")
    }

    /// FP: disable_standalone_number does not affect decimal +
    /// optional 量词 forms (Decimal+Measure path).
    func testDisableStandaloneNumberDoesNotBreakDecimals() {
        var cfg = ChineseITNConfig.default
        cfg.enableStandaloneNumber = false
        XCTAssertEqual(ChineseITN.normalize("三点一四", config: cfg), "3.14")
        XCTAssertEqual(ChineseITN.normalize("内存占用四点零八个G", config: cfg),
                       "内存占用4.08个G")
    }

    /// FP: disable_standalone_number does not affect dates or times.
    func testDisableStandaloneNumberDoesNotBreakDateTime() {
        var cfg = ChineseITNConfig.default
        cfg.enableStandaloneNumber = false
        XCTAssertEqual(ChineseITN.normalize("二零零八年", config: cfg), "2008年")
        XCTAssertEqual(ChineseITN.normalize("二零二六年五月四号", config: cfg), "2026/05/04")
        XCTAssertEqual(ChineseITN.normalize("三点半", config: cfg), "3:30")
    }

    // MARK: - enable_0_to_9

    /// TP: enable_0_to_9=true converts single Chinese digits
    /// standalone (一→1). Used by WeText's official test config.
    func testEnable0to9ConvertsSingleDigit() {
        var cfg = ChineseITNConfig.default
        cfg.enable0To9 = true
        XCTAssertEqual(ChineseITN.normalize("一", config: cfg), "1")
        XCTAssertEqual(ChineseITN.normalize("零", config: cfg), "0")
        XCTAssertEqual(ChineseITN.normalize("九", config: cfg), "9")
    }

    func testDefaultKeepsSingleDigit() {
        // enable_0_to_9=false (default): single digit stays Chinese
        // (avoids spurious conversion of "一个" / "一会" etc.).
        XCTAssertEqual(ChineseITN.normalize("一"), "一")
        XCTAssertEqual(ChineseITN.normalize("零"), "零")
    }

    // MARK: - remove_interjections

    /// TP: remove_interjections=true (default) strips 呃/啊 fillers.
    func testDefaultRemovesFillerInterjections() {
        XCTAssertEqual(ChineseITN.normalize("呃这个呃啊我不知道"), "这个我不知道")
        XCTAssertEqual(ChineseITN.normalize("啊好的"), "好的")
    }

    /// remove_interjections=false keeps them.
    func testDisableInterjectionRemovalKeepsFillers() {
        var cfg = ChineseITNConfig.default
        cfg.removeInterjections = false
        XCTAssertEqual(ChineseITN.normalize("呃这个呃啊我不知道", config: cfg),
                       "呃这个呃啊我不知道")
    }

    /// FP: remove_interjections does NOT affect numeric conversion.
    func testInterjectionFlagDoesNotAffectNumbers() {
        var cfg = ChineseITNConfig.default
        cfg.removeInterjections = false
        XCTAssertEqual(ChineseITN.normalize("内存占用四点零八个G", config: cfg),
                       "内存占用4.08个G")
        XCTAssertEqual(ChineseITN.normalize("两千五百万", config: cfg), "2500万")
    }

    // MARK: - Preset: weTextOfficialTest

    /// The preset bundles standalone=true + 0_to_9=true to match
    /// WeText's official-corpus test config.
    func testWeTextOfficialTestPreset() {
        let cfg = ChineseITNConfig.weTextOfficialTest
        XCTAssertEqual(ChineseITN.normalize("一", config: cfg), "1")
        XCTAssertEqual(ChineseITN.normalize("零", config: cfg), "0")
        XCTAssertEqual(ChineseITN.normalize("负一", config: cfg), "-1")
        // 万 still kept (preset does NOT enable million).
        XCTAssertEqual(ChineseITN.normalize("两千五百万", config: cfg), "2500万")
    }
}
