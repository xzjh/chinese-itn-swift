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

    // MARK: - enable_special_tilde

    /// Default (`enableSpecialTilde=false`): tilde-range output is
    /// NOT emitted. Instead the same span emits an identity candidate
    /// (output = input) at the same SpecialCardinal weight, so the
    /// lattice picks the verbatim Chinese phrase over any partial
    /// Cardinal sub-span match like "三五百" → "三500".
    func testSpecialTildeOffKeepsTildeKeysVerbatim() {
        // Pure digit pair (no Cardinal sub-span possible).
        XCTAssertEqual(ChineseITN.normalize("一二未知"), "一二未知")
        XCTAssertEqual(ChineseITN.normalize("三四明天到"), "三四明天到")
        // Tilde keys that overlap a valid Cardinal sub-span — identity
        // emit wins on cost vs char-fallback + Cardinal partial.
        XCTAssertEqual(ChineseITN.normalize("三五百"), "三五百")
        XCTAssertEqual(ChineseITN.normalize("五六十"), "五六十")
        XCTAssertEqual(ChineseITN.normalize("三四万"), "三四万")
        XCTAssertEqual(ChineseITN.normalize("一二十"), "一二十")
        XCTAssertEqual(ChineseITN.normalize("六七千"), "六七千")
    }

    /// Identity emit only applies to tilde-key spans. Plain valid
    /// Cardinal expressions (no tilde-key prefix) still convert.
    func testSpecialTildeOffDoesNotBlockPlainCardinals() {
        XCTAssertEqual(ChineseITN.normalize("五百"), "500")
        XCTAssertEqual(ChineseITN.normalize("六十"), "60")
        XCTAssertEqual(ChineseITN.normalize("一千二百三十四"), "1234")
    }

    /// TP: enable_special_tilde=true emits tilde ranges (WeText
    /// library behavior). Used by `.weTextLibraryDefault` /
    /// `.weTextOfficialTest` presets.
    func testEnableSpecialTildeProducesRanges() {
        var cfg = ChineseITNConfig.default
        cfg.enableSpecialTilde = true
        XCTAssertEqual(ChineseITN.normalize("一二未知", config: cfg), "1~2未知")
        XCTAssertEqual(ChineseITN.normalize("三五百", config: cfg), "300~500")
        XCTAssertEqual(ChineseITN.normalize("三四万", config: cfg), "3~4万")
        XCTAssertEqual(ChineseITN.normalize("五六十", config: cfg), "50~60")
    }

    /// FP: special_tilde flag does NOT change regular cardinals,
    /// decimals, or special_dash forms.
    func testSpecialTildeFlagDoesNotAffectOtherForms() {
        var cfg = ChineseITNConfig.default
        cfg.enableSpecialTilde = false
        // Regular cardinals
        XCTAssertEqual(ChineseITN.normalize("两千五百万", config: cfg), "2500万")
        // Decimal
        XCTAssertEqual(ChineseITN.normalize("三点一四", config: cfg), "3.14")
        // special_dash (separate feature — NOT gated by this flag)
        XCTAssertEqual(ChineseITN.normalize("十五六", config: cfg), "15-6")
        XCTAssertEqual(ChineseITN.normalize("七百三四十", config: cfg), "730-40")
    }

    // MARK: - enable_time_english_mapping

    /// Default (`enableTimeEnglishMapping=false`): noon prefix words
    /// stay Chinese; time portion still converts to HH:MM.
    func testDefaultKeepsNoonPrefixChinese() {
        XCTAssertEqual(ChineseITN.normalize("早上十点半"), "早上10:30")
        XCTAssertEqual(ChineseITN.normalize("下午三点四十五分"), "下午3:45")
        XCTAssertEqual(ChineseITN.normalize("晚上八点"), "晚上八点")  // hour-only → Cardinal/Decimal fall-through
        XCTAssertEqual(ChineseITN.normalize("上午十点零五分"), "上午10:05")
    }

    /// Default keeps time-unit words Chinese (分钟/小时/秒/毫秒/微秒).
    /// Other SI units (千克→kg, 公里→km) still convert.
    func testDefaultKeepsTimeUnitsChinese() {
        XCTAssertEqual(ChineseITN.normalize("等二十分钟"), "等20分钟")
        XCTAssertEqual(ChineseITN.normalize("两个小时"), "两个小时")  // 个 不是unit, 两 单digit
        XCTAssertEqual(ChineseITN.normalize("跑十公里"), "跑10km")
        XCTAssertEqual(ChineseITN.normalize("重二十千克"), "重20kg")
        XCTAssertEqual(ChineseITN.normalize("延迟一百毫秒"), "延迟100毫秒")
        XCTAssertEqual(ChineseITN.normalize("十二个小时"), "12个小时")
    }

    /// TP: enable_time_english_mapping=true converts noon prefix and
    /// time units to English short forms (WeText library behavior).
    func testEnableTimeEnglishMappingConverts() {
        var cfg = ChineseITNConfig.default
        cfg.enableTimeEnglishMapping = true
        XCTAssertEqual(ChineseITN.normalize("早上十点半", config: cfg), "10:30a.m.")
        XCTAssertEqual(ChineseITN.normalize("下午三点四十五分", config: cfg), "3:45p.m.")
        XCTAssertEqual(ChineseITN.normalize("等二十分钟", config: cfg), "等20min")
        XCTAssertEqual(ChineseITN.normalize("延迟一百毫秒", config: cfg), "延迟100ms")
    }

    /// FP: time mapping flag does NOT affect other measure units or
    /// decimals.
    func testTimeMappingFlagDoesNotAffectOtherUnits() {
        var cfg = ChineseITNConfig.default
        cfg.enableTimeEnglishMapping = false
        XCTAssertEqual(ChineseITN.normalize("跑十公里", config: cfg), "跑10km")
        XCTAssertEqual(ChineseITN.normalize("重二十千克", config: cfg), "重20kg")
        XCTAssertEqual(ChineseITN.normalize("三点一四", config: cfg), "3.14")
    }

    /// Words not in the noon map ("凌晨") are unaffected by the flag —
    /// they always stay Chinese.
    func testNoonPrefixNotInMapAlwaysKept() {
        for cfg in [ChineseITNConfig.default,
                    ChineseITNConfig.weTextLibraryDefault] {
            XCTAssertEqual(
                ChineseITN.normalize("凌晨三点半", config: cfg), "凌晨3:30")
        }
    }

    // MARK: - 几X family whitelist

    /// `几十/几百/几千/...` style approximate quantifiers are whitelist-
    /// protected, so WeText's "半converted" `几10/几100/几1000` output
    /// is replaced by the verbatim Chinese phrase.
    func testJiFamilyKeptVerbatim() {
        let phrases = [
            "几十", "几百", "几千", "几万",
            "几十万", "几百万", "几千万",
            "几亿", "几十亿", "几百亿", "几千亿", "几万亿",
        ]
        for phrase in phrases {
            XCTAssertEqual(ChineseITN.normalize(phrase), phrase,
                           "Ji-quantifier should stay Chinese: \(phrase)")
        }
    }

    /// 几X embedded in a sentence keeps the phrase, surrounding
    /// numeric content still normalizes.
    func testJiFamilyInSentence() {
        XCTAssertEqual(
            ChineseITN.normalize("几十、一百个字符"),
            "几十、100个字符")
        XCTAssertEqual(
            ChineseITN.normalize("总共几千万人"),
            "总共几千万人")
        XCTAssertEqual(
            ChineseITN.normalize("几亿人民"),
            "几亿人民")
    }

    /// 几X protection applies under all configs (it's whitelist,
    /// not flag-gated).
    func testJiFamilyKeptUnderWeTextPresets() {
        for cfg in [ChineseITNConfig.weTextLibraryDefault,
                    ChineseITNConfig.weTextOfficialTest] {
            XCTAssertEqual(ChineseITN.normalize("几十", config: cfg), "几十")
            XCTAssertEqual(ChineseITN.normalize("几亿", config: cfg), "几亿")
        }
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
