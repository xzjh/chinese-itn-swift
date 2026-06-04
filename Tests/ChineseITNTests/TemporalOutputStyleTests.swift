import XCTest
@testable import ChineseITN

final class TemporalOutputStyleTests: XCTestCase {

    func testCompactNumericKeepsLegacyDateAndClockShapes() {
        var cfg = ChineseITNConfig.default
        cfg.temporalOutputStyle = .compactNumeric

        XCTAssertEqual(ChineseITN.normalize("六月七号", config: cfg), "06/07")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七号", config: cfg), "2027/06/07")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月", config: cfg), "2027/06")
        XCTAssertEqual(ChineseITN.normalize("二零二七年", config: cfg), "2027年")
        XCTAssertEqual(ChineseITN.normalize("五点三十一分", config: cfg), "5:31")
        XCTAssertEqual(ChineseITN.normalize("五点三十一分九秒", config: cfg), "5:31:09")
        XCTAssertEqual(ChineseITN.normalize("六月七号五点三十一分", config: cfg), "06/07 5:31")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七号五点三十一分", config: cfg), "2027/06/07 5:31")
    }

    func testChineseNumericKeepsChineseDateAndClockUnits() {
        var cfg = ChineseITNConfig.default
        cfg.temporalOutputStyle = .chineseNumeric

        XCTAssertEqual(ChineseITN.normalize("六月七号", config: cfg), "6月7号")
        XCTAssertEqual(ChineseITN.normalize("六月七日", config: cfg), "6月7日")
        XCTAssertEqual(ChineseITN.normalize("六月七號", config: cfg), "6月7號")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七号", config: cfg), "2027年6月7号")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七日", config: cfg), "2027年6月7日")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月", config: cfg), "2027年6月")
        XCTAssertEqual(ChineseITN.normalize("二零二七年", config: cfg), "2027年")
        XCTAssertEqual(ChineseITN.normalize("五点三十一分", config: cfg), "5点31分")
        XCTAssertEqual(ChineseITN.normalize("五点零五分六秒", config: cfg), "5点05分06秒")
        XCTAssertEqual(ChineseITN.normalize("六月七号五点三十一分", config: cfg), "6月7号 5点31分")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七号五点三十一分", config: cfg), "2027年6月7号 5点31分")
    }

    func testSpokenChinesePreservesDateAndClockSpans() {
        var cfg = ChineseITNConfig.default
        cfg.temporalOutputStyle = .spokenChinese

        XCTAssertEqual(ChineseITN.normalize("六月七号", config: cfg), "六月七号")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七号", config: cfg), "二零二七年六月七号")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月", config: cfg), "二零二七年六月")
        XCTAssertEqual(ChineseITN.normalize("二零二七年", config: cfg), "二零二七年")
        XCTAssertEqual(ChineseITN.normalize("五点三十一分", config: cfg), "五点三十一分")
        XCTAssertEqual(ChineseITN.normalize("五点三十一分九秒", config: cfg), "五点三十一分九秒")
        XCTAssertEqual(ChineseITN.normalize("六月七号五点三十一分", config: cfg), "六月七号五点三十一分")
        XCTAssertEqual(ChineseITN.normalize("二零二七年六月七号五点三十一分", config: cfg), "二零二七年六月七号五点三十一分")
    }

    func testChineseTemporalStylesKeepNoonPrefixChinese() {
        var numeric = ChineseITNConfig.default
        numeric.temporalOutputStyle = .chineseNumeric
        numeric.enableTimeEnglishMapping = true

        var spoken = ChineseITNConfig.default
        spoken.temporalOutputStyle = .spokenChinese
        spoken.enableTimeEnglishMapping = true

        XCTAssertEqual(ChineseITN.normalize("早上五点三十一分", config: numeric), "早上5点31分")
        XCTAssertEqual(ChineseITN.normalize("下午五点三十一分", config: numeric), "下午5点31分")
        XCTAssertEqual(ChineseITN.normalize("早上五点三十一分", config: spoken), "早上五点三十一分")
        XCTAssertEqual(ChineseITN.normalize("下午五点三十一分", config: spoken), "下午五点三十一分")
    }

    func testTemporalStyleDoesNotChangeDurationUnits() {
        for style in ChineseITNTemporalOutputStyle.allCases {
            var cfg = ChineseITNConfig.default
            cfg.temporalOutputStyle = style

            XCTAssertEqual(ChineseITN.normalize("等二十分钟", config: cfg), "等20分钟")
            XCTAssertEqual(ChineseITN.normalize("延迟一百毫秒", config: cfg), "延迟100毫秒")
        }
    }
}
