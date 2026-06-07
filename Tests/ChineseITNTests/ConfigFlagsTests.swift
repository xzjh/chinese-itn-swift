// ConfigFlagsTests.swift
// Product configuration contract tests. These pin the behavior we
// expose to callers, not byte-for-byte WeText parity.

import XCTest
@testable import ChineseITN

final class ConfigFlagsTests: XCTestCase {

    // MARK: - enable_million

    func testEnableMillionExpandsManSuffix() {
        var cfg = ChineseITNConfig.default
        cfg.enableMillion = true
        XCTAssertEqual(ChineseITN.normalize("两千五百万", config: cfg), "25000000")
        XCTAssertEqual(ChineseITN.normalize("一千万", config: cfg), "10000000")
        XCTAssertEqual(ChineseITN.normalize("三百万", config: cfg), "3000000")
    }

    func testDefaultKeepsReadableWanAndYiMarkers() {
        XCTAssertEqual(ChineseITN.normalize("两千五百万"), "2500万")
        XCTAssertEqual(ChineseITN.normalize("三亿五千万"), "3亿5000万")
        XCTAssertEqual(ChineseITN.normalize("幺三八幺幺幺零零零零零"), "13811100000")
    }

    // MARK: - enable_standalone_number

    func testDisableStandaloneNumberKeepsBareCardinals() {
        var cfg = ChineseITNConfig.default
        cfg.enableStandaloneNumber = false
        XCTAssertEqual(ChineseITN.normalize("两万", config: cfg), "两万")
        XCTAssertEqual(ChineseITN.normalize("三十五", config: cfg), "三十五")
        XCTAssertEqual(ChineseITN.normalize("一百二十", config: cfg), "一百二十")
    }

    func testDisableStandaloneNumberStillAllowsAnchoredForms() {
        var cfg = ChineseITNConfig.default
        cfg.enableStandaloneNumber = false
        XCTAssertEqual(ChineseITN.normalize("二十五千克", config: cfg), "25千克")
        XCTAssertEqual(ChineseITN.normalize("两百欧元", config: cfg), "200欧元")
        XCTAssertEqual(ChineseITN.normalize("百分之三十", config: cfg), "30%")
        XCTAssertEqual(ChineseITN.normalize("三点一四", config: cfg), "3.14")
        XCTAssertEqual(ChineseITN.normalize("二零二六年五月四号", config: cfg), "2026/05/04")
    }

    // MARK: - enable_0_to_9

    func testEnable0To9ConvertsSingleDigits() {
        var cfg = ChineseITNConfig.default
        cfg.enable0To9 = true
        XCTAssertEqual(ChineseITN.normalize("一", config: cfg), "1")
        XCTAssertEqual(ChineseITN.normalize("零", config: cfg), "0")
        XCTAssertEqual(ChineseITN.normalize("九", config: cfg), "9")
    }

    func testDefaultKeepsStandaloneSingleDigits() {
        XCTAssertEqual(ChineseITN.normalize("一"), "一")
        XCTAssertEqual(ChineseITN.normalize("零"), "零")
    }

    // MARK: - remove_interjections

    func testDefaultRemovesFillerInterjections() {
        XCTAssertEqual(ChineseITN.normalize("呃这个呃啊我不知道"), "这个我不知道")
        XCTAssertEqual(ChineseITN.normalize("啊好的"), "好的")
    }

    func testDisableInterjectionRemovalKeepsFillers() {
        var cfg = ChineseITNConfig.default
        cfg.removeInterjections = false
        XCTAssertEqual(ChineseITN.normalize("呃这个呃啊我不知道", config: cfg),
                       "呃这个呃啊我不知道")
    }

    // MARK: - unitOutputStyle

    func testDefaultUnitStyleKeepsChineseUnits() {
        XCTAssertEqual(ChineseITN.normalize("二千克"), "二千克")
        XCTAssertEqual(ChineseITN.normalize("二十五千克"), "25千克")
        XCTAssertEqual(ChineseITN.normalize("跑十公里"), "跑10公里")
        XCTAssertEqual(ChineseITN.normalize("等二十分钟"), "等20分钟")
        XCTAssertEqual(ChineseITN.normalize("延迟一百毫秒"), "延迟100毫秒")
    }

    func testUnitSymbolStyleUsesSymbolsAndNormalizesUnitNumbers() {
        var cfg = ChineseITNConfig.default
        cfg.unitOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二千克", config: cfg), "2 kg")
        XCTAssertEqual(ChineseITN.normalize("二十五千克", config: cfg), "25 kg")
        XCTAssertEqual(ChineseITN.normalize("跑十公里", config: cfg), "跑10 km")
        XCTAssertEqual(ChineseITN.normalize("等二十分钟", config: cfg), "等20 min")
        XCTAssertEqual(ChineseITN.normalize("延迟一百毫秒", config: cfg), "延迟100 ms")
        XCTAssertEqual(ChineseITN.normalize("二万吨", config: cfg), "2万吨")
    }

    // MARK: - currencyOutputStyle

    func testDefaultCurrencyStyleKeepsChineseSuffixUnits() {
        XCTAssertEqual(ChineseITN.normalize("一千美元"), "1000美元")
        XCTAssertEqual(ChineseITN.normalize("一点二五美元"), "1.25美元")
        XCTAssertEqual(ChineseITN.normalize("二万元"), "二万元")
        XCTAssertEqual(ChineseITN.normalize("二亿元"), "二亿元")
        XCTAssertEqual(ChineseITN.normalize("两千五百万美元"), "2500万美元")
        XCTAssertEqual(ChineseITN.normalize("三千三百八十元五角八分"), "3380元5角8分")
    }

    func testCurrencySymbolStyleUsesSymbolsAndNormalizesCurrencyNumbers() {
        var cfg = ChineseITNConfig.default
        cfg.currencyOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("一千美元", config: cfg), "$1000")
        XCTAssertEqual(ChineseITN.normalize("一点二五美元", config: cfg), "$1.25")
        XCTAssertEqual(ChineseITN.normalize("二到四美元", config: cfg), "$2到$4")
        XCTAssertEqual(ChineseITN.normalize("二万到四万美元", config: cfg), "$2万到$4万")
        XCTAssertEqual(ChineseITN.normalize("两千五百万美元", config: cfg), "$2500万")
        XCTAssertEqual(ChineseITN.normalize("三千三百八十元五角八分", config: cfg), "¥3380.58")
    }

    // MARK: - rangeOutputStyle

    func testDefaultRangeStyleUsesChineseConnector() {
        XCTAssertEqual(ChineseITN.normalize("二到四"), "二到四")
        XCTAssertEqual(ChineseITN.normalize("二到四万"), "二到四万")
        XCTAssertEqual(ChineseITN.normalize("二万到四万"), "二万到四万")
        XCTAssertEqual(ChineseITN.normalize("二到四亿"), "二到四亿")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿"), "二亿到四亿")
        XCTAssertEqual(ChineseITN.normalize("百分之三十到四十一"), "30%到41%")
    }

    func testRangeSymbolStyleOnlyChangesConnector() {
        var cfg = ChineseITNConfig.default
        cfg.rangeOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四", config: cfg), "二~四")
        XCTAssertEqual(ChineseITN.normalize("二到四万", config: cfg), "二~四万")
        XCTAssertEqual(ChineseITN.normalize("二万到四万", config: cfg), "二万~四万")
        XCTAssertEqual(ChineseITN.normalize("二到四亿", config: cfg), "二~四亿")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿", config: cfg), "二亿~四亿")
        XCTAssertEqual(ChineseITN.normalize("百分之三十到四十一", config: cfg), "30%~41%")
    }

    func testEnable0To9ControlsRangeEndpointDigits() {
        var cfg = ChineseITNConfig.default
        cfg.enable0To9 = true
        XCTAssertEqual(ChineseITN.normalize("二到四", config: cfg), "2到4")
        XCTAssertEqual(ChineseITN.normalize("二到四万", config: cfg), "2到4万")
        XCTAssertEqual(ChineseITN.normalize("二万到四万", config: cfg), "2万到4万")
        XCTAssertEqual(ChineseITN.normalize("二到四亿", config: cfg), "2到4亿")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿", config: cfg), "2亿到4亿")

        cfg.rangeOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四万", config: cfg), "2~4万")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿", config: cfg), "2亿~4亿")
    }

    func testUnitAndCurrencyStylesCombineWithRangeStyle() {
        var cfg = ChineseITNConfig.default
        cfg.unitOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四千克", config: cfg), "2到4 kg")

        cfg.rangeOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四千克", config: cfg), "2~4 kg")

        cfg.currencyOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四美元", config: cfg), "$2~$4")
    }

    // MARK: - spokenRangeStyle

    func testDefaultSpokenRangesArePreserved() {
        XCTAssertEqual(ChineseITN.normalize("三五百"), "三五百")
        XCTAssertEqual(ChineseITN.normalize("八九千美元"), "八九千美元")
        XCTAssertEqual(ChineseITN.normalize("十五六"), "十五六")
        XCTAssertEqual(ChineseITN.normalize("十五六美元"), "十五六美元")
    }

    func testSpokenRangeExpandUsesConfiguredConnectorAndUnitStyles() {
        var cfg = ChineseITNConfig.default
        cfg.spokenRangeStyle = .expand
        XCTAssertEqual(ChineseITN.normalize("三五百", config: cfg), "300到500")
        XCTAssertEqual(ChineseITN.normalize("八九千美元", config: cfg), "8000到9000美元")
        XCTAssertEqual(ChineseITN.normalize("十五六", config: cfg), "15到16")
        XCTAssertEqual(ChineseITN.normalize("十五六美元", config: cfg), "15到16美元")

        cfg.rangeOutputStyle = .symbol
        cfg.unitOutputStyle = .symbol
        cfg.currencyOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("三五百公里", config: cfg), "300~500 km")
        XCTAssertEqual(ChineseITN.normalize("十五六美元", config: cfg), "$15~$16")
    }

    func testStyleCombinationMatrix() {
        for unitStyle in ChineseITNUnitOutputStyle.allCases {
            for currencyStyle in ChineseITNCurrencyOutputStyle.allCases {
                for rangeStyle in ChineseITNRangeOutputStyle.allCases {
                    for spokenStyle in ChineseITNSpokenRangeStyle.allCases {
                        var cfg = ChineseITNConfig.default
                        cfg.unitOutputStyle = unitStyle
                        cfg.currencyOutputStyle = currencyStyle
                        cfg.rangeOutputStyle = rangeStyle
                        cfg.spokenRangeStyle = spokenStyle

                        let connector = rangeStyle == .symbol ? "~" : "到"
                        let expectedUnitRange = unitStyle == .symbol
                            ? "2\(connector)4 kg"
                            : "二\(connector)四千克"
                        let expectedCurrencyRange = currencyStyle == .symbol
                            ? "$2\(connector)$4"
                            : "二\(connector)四美元"
                        let expectedSpokenMoney: String
                        if spokenStyle == .preserve {
                            expectedSpokenMoney = "十五六美元"
                        } else if currencyStyle == .symbol {
                            expectedSpokenMoney = "$15\(connector)$16"
                        } else {
                            expectedSpokenMoney = "15\(connector)16美元"
                        }

                        XCTAssertEqual(
                            ChineseITN.normalize("二到四千克", config: cfg),
                            expectedUnitRange,
                            "unit=\(unitStyle), currency=\(currencyStyle), range=\(rangeStyle), spoken=\(spokenStyle)"
                        )
                        XCTAssertEqual(
                            ChineseITN.normalize("二到四美元", config: cfg),
                            expectedCurrencyRange,
                            "unit=\(unitStyle), currency=\(currencyStyle), range=\(rangeStyle), spoken=\(spokenStyle)"
                        )
                        XCTAssertEqual(
                            ChineseITN.normalize("十五六美元", config: cfg),
                            expectedSpokenMoney,
                            "unit=\(unitStyle), currency=\(currencyStyle), range=\(rangeStyle), spoken=\(spokenStyle)"
                        )
                    }
                }
            }
        }
    }

    // MARK: - temporalOutputStyle

    func testTemporalStyles() {
        XCTAssertEqual(ChineseITN.normalize("二零二六年五月四号"), "2026/05/04")
        XCTAssertEqual(ChineseITN.normalize("六月七号"), "06/07")
        XCTAssertEqual(ChineseITN.normalize("下午三点四十五分"), "下午3:45")
        XCTAssertEqual(ChineseITN.normalize("三点半"), "3:30")

        var chinese = ChineseITNConfig.default
        chinese.temporalOutputStyle = .chineseNumeric
        XCTAssertEqual(ChineseITN.normalize("二零二六年五月四号", config: chinese),
                       "2026年5月4号")
        XCTAssertEqual(ChineseITN.normalize("下午三点四十五分", config: chinese),
                       "下午3点45分")

        var spoken = ChineseITNConfig.default
        spoken.temporalOutputStyle = .spokenChinese
        XCTAssertEqual(ChineseITN.normalize("二零二六年五月四号", config: spoken),
                       "二零二六年五月四号")
        XCTAssertEqual(ChineseITN.normalize("三点半", config: spoken), "三点半")
    }

    // MARK: - whitelist and fixed false positives

    func testJiFamilyKeptVerbatim() {
        let phrases = [
            "几十", "几百", "几千", "几万",
            "几十万", "几百万", "几千万",
            "几亿", "几十亿", "几百亿", "几千亿", "几万亿",
        ]
        for phrase in phrases {
            XCTAssertEqual(ChineseITN.normalize(phrase), phrase)
        }
    }

    func testCoreProtectionStillWorks() {
        XCTAssertEqual(ChineseITN.normalize("百闻不如一见"), "百闻不如一见")
        XCTAssertEqual(ChineseITN.normalize("一个"), "一个")
        XCTAssertEqual(ChineseITN.normalize("一会"), "一会")
        XCTAssertEqual(ChineseITN.normalize("京A幺二三四五"), "京A12345")
        XCTAssertEqual(ChineseITN.normalize("w w w 点 baidu 点 com"), "www.baidu.com")
    }
}
