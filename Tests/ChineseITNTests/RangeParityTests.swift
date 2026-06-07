// RangeParityTests.swift
// Product range behavior around 万/亿, units, and currency. The file
// name is kept for continuity with the earlier parity-focused tests.

import XCTest
@testable import ChineseITN

final class RangeParityTests: XCTestCase {

    func testDefaultRangesUseChineseConnectorAndPreserveSingleDigitEndpoints() {
        XCTAssertEqual(ChineseITN.normalize("二到四"), "二到四")
        XCTAssertEqual(ChineseITN.normalize("二到四万"), "二到四万")
        XCTAssertEqual(ChineseITN.normalize("二万到四万"), "二万到四万")
        XCTAssertEqual(ChineseITN.normalize("二到四亿"), "二到四亿")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿"), "二亿到四亿")
        XCTAssertEqual(ChineseITN.normalize("二到四万吨"), "二到四万吨")
        XCTAssertEqual(ChineseITN.normalize("二到四美元"), "二到四美元")
    }

    func testEnable0To9ArabicizesSingleDigitRangeEndpoints() {
        var cfg = ChineseITNConfig.default
        cfg.enable0To9 = true
        XCTAssertEqual(ChineseITN.normalize("二到四", config: cfg), "2到4")
        XCTAssertEqual(ChineseITN.normalize("二到四万", config: cfg), "2到4万")
        XCTAssertEqual(ChineseITN.normalize("二万到四万", config: cfg), "2万到4万")
        XCTAssertEqual(ChineseITN.normalize("二到四亿", config: cfg), "2到4亿")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿", config: cfg), "2亿到4亿")
        XCTAssertEqual(ChineseITN.normalize("二到四万吨", config: cfg), "2到4万吨")
        XCTAssertEqual(ChineseITN.normalize("二到四美元", config: cfg), "2到4美元")
    }

    func testRangeSymbolChangesConnectorOnly() {
        var cfg = ChineseITNConfig.default
        cfg.rangeOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四", config: cfg), "二~四")
        XCTAssertEqual(ChineseITN.normalize("二到四万", config: cfg), "二~四万")
        XCTAssertEqual(ChineseITN.normalize("二万到四万", config: cfg), "二万~四万")
        XCTAssertEqual(ChineseITN.normalize("二到四亿", config: cfg), "二~四亿")
        XCTAssertEqual(ChineseITN.normalize("二亿到四亿", config: cfg), "二亿~四亿")
        XCTAssertEqual(ChineseITN.normalize("二到四万吨", config: cfg), "二~四万吨")
        XCTAssertEqual(ChineseITN.normalize("二到四美元", config: cfg), "二~四美元")
    }

    func testUnitAndCurrencySymbolRangesForceArabicEndpoints() {
        var unit = ChineseITNConfig.default
        unit.unitOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四千克", config: unit), "2到4 kg")
        XCTAssertEqual(ChineseITN.normalize("跑二到四公里", config: unit), "跑2到4 km")

        unit.rangeOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四千克", config: unit), "2~4 kg")
        XCTAssertEqual(ChineseITN.normalize("跑二到四公里", config: unit), "跑2~4 km")

        var money = ChineseITNConfig.default
        money.currencyOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四美元", config: money), "$2到$4")
        XCTAssertEqual(ChineseITN.normalize("二万到四万美元", config: money), "$2万到$4万")

        money.rangeOutputStyle = .symbol
        XCTAssertEqual(ChineseITN.normalize("二到四美元", config: money), "$2~$4")
        XCTAssertEqual(ChineseITN.normalize("二万到四万美元", config: money), "$2万~$4万")
    }

    func testReportedSentenceUsesProductRangeShape() {
        XCTAssertEqual(
            ChineseITN.normalize("非洲罗非鱼养殖规划二到四万吨，有望做到二到四亿利润。"),
            "非洲罗非鱼养殖规划二到四万吨，有望做到二到四亿利润。"
        )

        var cfg = ChineseITNConfig.default
        cfg.enable0To9 = true
        XCTAssertEqual(
            ChineseITN.normalize("非洲罗非鱼养殖规划二到四万吨，有望做到二到四亿利润。", config: cfg),
            "非洲罗非鱼养殖规划2到4万吨，有望做到2到4亿利润。"
        )
    }
}
