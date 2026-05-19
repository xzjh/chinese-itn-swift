// ModuleTests.swift
// Per-module unit tests, independent of parity fixtures.

import XCTest
@testable import ChineseITN

final class DecimalTests: XCTestCase {

    func testSimpleDecimal() {
        XCTAssertEqual(Decimal.normalize("三点二三"), "3.23")
        XCTAssertEqual(Decimal.normalize("二点五"), "2.5")
    }

    func testWithLeadingZero() {
        XCTAssertEqual(Decimal.normalize("四点零八"), "4.08")
        XCTAssertEqual(Decimal.normalize("五点零零一"), "5.001")
    }

    func testTwoDigitInteger() {
        XCTAssertEqual(Decimal.normalize("六十五点三"), "65.3")
    }

    func testInSentence() {
        XCTAssertEqual(
            Decimal.normalize("内存占用四点零八G"),
            "内存占用4.08G"
        )
    }

    func testDecimalWithCounter() {
        XCTAssertEqual(
            Decimal.normalize("原来你是四点零八个G"),
            "原来你是4.08个G"
        )
    }

    func testNoDecimal() {
        XCTAssertEqual(Decimal.normalize("我说一句话"), "我说一句话")
    }
}

final class TimeNormalizeTests: XCTestCase {

    func testHourWithMinute() {
        XCTAssertEqual(TimeNormalize.normalize("三点四十五分"), "3:45")
    }

    func testHourWithBan() {
        XCTAssertEqual(TimeNormalize.normalize("三点半"), "3:30")
    }

    func testNoonPrefixMapsToAMPM() {
        XCTAssertEqual(TimeNormalize.normalize("下午三点四十五分"), "3:45p.m.")
        XCTAssertEqual(TimeNormalize.normalize("上午十点零五分"), "10:05a.m.")
    }

    func testNoonPrefixUnmappedKept() {
        // 凌晨 not in noon map; kept Chinese
        XCTAssertEqual(TimeNormalize.normalize("凌晨三点半"), "凌晨3:30")
    }

    func testHourOnlyNotTouched() {
        // Without minute info, Time falls through (Cardinal handles)
        XCTAssertEqual(TimeNormalize.normalize("下午三点"), "下午三点")
    }
}

final class FractionTests: XCTestCase {

    func testPercentBasic() {
        XCTAssertEqual(Fraction.normalize("百分之三十"), "30%")
        XCTAssertEqual(Fraction.normalize("百分之二"), "2%")
        XCTAssertEqual(Fraction.normalize("百分之一百"), "100%")  // depends on parseToInt for "一百"
    }

    func testGeneralFraction() {
        XCTAssertEqual(Fraction.normalize("三分之二"), "2/3")
        XCTAssertEqual(Fraction.normalize("二分之一"), "1/2")
    }

    func testThousandFractionNotHandled() {
        // WeText leaves 千分之X / 万分之X unchanged.
        // Our pattern requires digit denominator, so 千 doesn't match.
        XCTAssertEqual(Fraction.normalize("千分之五"), "千分之五")
    }
}

final class MoneyTests: XCTestCase {

    func testEuro() {
        XCTAssertEqual(Money.normalize("两百欧元"), "€200")
        XCTAssertEqual(Money.normalize("一千欧元"), "€1000")
    }

    func testUSD() {
        XCTAssertEqual(Money.normalize("一千美元"), "$1000")
    }

    func testGBP() {
        XCTAssertEqual(Money.normalize("五百英镑"), "£500")
    }

    func testNonSymbolCurrency() {
        // 美金 not in symbol.tsv → no swap; Cardinal handles digit
        // (Note: Money.normalize alone won't convert "一千" → "1000"
        //  because 美金 isn't in symbol map. ChineseITN.normalize
        //  composes Cardinal after Money so the full pipeline
        //  produces "1000美金".)
        XCTAssertEqual(Money.normalize("一千美金"), "一千美金")
    }
}

final class WhitelistTests: XCTestCase {

    func testIdiomProtected() {
        XCTAssertEqual(ChineseITN.normalize("百闻不如一见"), "百闻不如一见")
        XCTAssertEqual(ChineseITN.normalize("做事不能三心二意"), "做事不能三心二意")
    }

    func testCounterExpression() {
        XCTAssertEqual(ChineseITN.normalize("我说一句话"), "我说一句话")
        XCTAssertEqual(ChineseITN.normalize("再来一杯"), "再来一杯")
    }

    func testWeekday() {
        XCTAssertEqual(ChineseITN.normalize("星期一开会"), "星期一开会")
    }

    func testProperNoun() {
        XCTAssertEqual(ChineseITN.normalize("我去过九寨沟"), "我去过九寨沟")
        XCTAssertEqual(ChineseITN.normalize("三国演义"), "三国演义")
    }

    func testIdiomPlusDecimal() {
        let out = ChineseITN.normalize("我有四点零八G内存，做事不能三心二意")
        XCTAssertTrue(out.contains("4.08G"))
        XCTAssertTrue(out.contains("三心二意"))
    }
}

final class UserScenarioTests: XCTestCase {

    // Real ASR transcripts from production hush·hush dictation history
    // that motivated this library. Each test is the verbatim raw input.

    func testCase1_decimalShort() {
        let input = "我刚才启动之后内存占用四点零八G但是说完一句话之后变成四变成四点三三G了"
        let out = ChineseITN.normalize(input)
        XCTAssertTrue(out.contains("4.08G"))
        XCTAssertTrue(out.contains("4.33G"))
        XCTAssertTrue(out.contains("一句话"))   // counter expression preserved
    }

    func testCase2_decimalWithCounter() {
        let input = "原来你是四点零八个G我说完之后你会变到四点三三个G"
        let out = ChineseITN.normalize(input)
        XCTAssertTrue(out.contains("4.08个G"))
        XCTAssertTrue(out.contains("4.33个G"))
    }

    func testCase3_bareDecimal() {
        XCTAssertEqual(ChineseITN.normalize("三点二三"), "3.23")
    }

    func testCase4_decimalWithG() {
        let input = "为什么我的Activity Monitor里面显示的是四点三个G呢"
        let out = ChineseITN.normalize(input)
        XCTAssertTrue(out.contains("4.3个G"))
    }
}
