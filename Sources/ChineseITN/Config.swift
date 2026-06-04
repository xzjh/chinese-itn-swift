// Config.swift
// Runtime configuration mirroring WeTextProcessing's
// InverseNormalizer() / Cardinal() flags. See
// https://github.com/wenet-e2e/WeTextProcessing/blob/master/itn/chinese/inverse_normalizer.py
//
//   enable_standalone_number: when False, a bare cardinal expression
//       not bound to a unit / decimal / money / time / date is kept
//       in Chinese. WeText library default: True.
//   enable_0_to_9: when True, single Chinese digits (一..九, 零) are
//       in scope for standalone conversion (一 → 1). When False, only
//       expressions containing a unit char (十/百/千/万/亿) can be
//       standalone-converted. WeText library default: False.
//       WeText OFFICIAL TEST CONFIG: True.
//   enable_million: extends the 万 prefix to include thousand/hundred/
//       teen multipliers (一千万 → 10000000 vs 1000万). WeText default
//       and official test config: False.
//   remove_interjections: when True, blacklist fillers (呃, 啊) are
//       removed from the output. WeText library default: True.
//   enable_special_tilde: when True, spoken approximate ranges like
//       "一二", "三五百", "三四万" map to tilde ranges ("1~2", "300~500",
//       "3~4万"). When False, these stay in Chinese — useful when a
//       downstream LLM will decide range form, and when "一二/三四"
//       style sequences are more often digit-streams than ranges in the
//       target domain (e.g. ASR transcripts of version numbers, IDs).
//       WeText library default: True. Our library default: False.
//   enable_time_english_mapping: when True, time-related Chinese spans
//       map to English short forms — noon prefixes (早上/上午/早晨 →
//       a.m., 下午/晚上/傍晚 → p.m.) and time units (分钟→min, 小时→h,
//       秒→s, 毫秒→ms, 微秒→μs, 纳秒→ns, 皮秒→ps). When False, both stay
//       Chinese ("早上十点半" → "早上10:30", "二十分钟" → "20分钟"),
//       leaving range / approximate-quantifier interpretation to a
//       downstream LLM. WeText library default: True. Our library
//       default: False.
//   temporal_output_style: controls date and clock-time surface forms.
//       Compact preserves the legacy slash/colon shape
//       ("五月十号" → "05/10", "五点三十一分" → "5:31").
//       Chinese numeric keeps Chinese date/time units but arabizes the
//       numbers while preserving the spoken day suffix
//       ("五月十号" → "5月10号", "五月十日" → "5月10日",
//       "五点三十一分" → "5点31分").
//       Spoken Chinese preserves matched date/time spans verbatim.

import Foundation

public enum ChineseITNTemporalOutputStyle: String, Sendable, CaseIterable {
    case compactNumeric
    case chineseNumeric
    case spokenChinese
}

public struct ChineseITNConfig: Sendable {

    public var enableStandaloneNumber: Bool
    public var enable0To9: Bool
    public var enableMillion: Bool
    public var removeInterjections: Bool
    public var enableSpecialTilde: Bool
    public var enableTimeEnglishMapping: Bool
    public var temporalOutputStyle: ChineseITNTemporalOutputStyle

    public init(
        enableStandaloneNumber: Bool = true,
        enable0To9: Bool = false,
        enableMillion: Bool = false,
        removeInterjections: Bool = true,
        enableSpecialTilde: Bool = false,
        enableTimeEnglishMapping: Bool = false,
        temporalOutputStyle: ChineseITNTemporalOutputStyle = .compactNumeric
    ) {
        self.enableStandaloneNumber = enableStandaloneNumber
        self.enable0To9 = enable0To9
        self.enableMillion = enableMillion
        self.removeInterjections = removeInterjections
        self.enableSpecialTilde = enableSpecialTilde
        self.enableTimeEnglishMapping = enableTimeEnglishMapping
        self.temporalOutputStyle = temporalOutputStyle
    }

    /// Library default. Diverges from WeText library defaults on
    /// `enableSpecialTilde` (we default to False — see field doc above).
    public static let `default` = ChineseITNConfig()

    /// Matches WeText's `InverseNormalizer()` no-arg constructor. Use
    /// when validating against fixtures generated from upstream
    /// (RobustnessTests).
    public static let weTextLibraryDefault = ChineseITNConfig(
        enableStandaloneNumber: true,
        enable0To9: false,
        enableMillion: false,
        removeInterjections: true,
        enableSpecialTilde: true,
        enableTimeEnglishMapping: true
    )

    /// Matches the config used by WeText's official test suite at
    /// itn/chinese/test/normalizer_test.py — i.e. what produced the
    /// expected outputs in test/data/*.txt. Used by OfficialParityTests.
    public static let weTextOfficialTest = ChineseITNConfig(
        enableStandaloneNumber: true,
        enable0To9: true,
        enableMillion: false,
        removeInterjections: true,
        enableSpecialTilde: true,
        enableTimeEnglishMapping: true
    )
}
