// Config.swift
// Runtime configuration for product-facing Chinese ITN output.
//
//   enable_standalone_number: when False, a bare cardinal expression
//       not bound to a unit / decimal / money / time / date is kept
//       in Chinese.
//   enable_0_to_9: when True, single Chinese digits (一..九, 零) are
//       in scope for standalone conversion and range endpoints
//       (一 → 1, 二到四万 → 2到4万).
//   enable_million: extends the 万 prefix to include thousand/hundred/
//       teen multipliers (一千万 → 10000000 vs 1000万).
//   remove_interjections: when True, blacklist fillers (呃, 啊) are
//       removed from the output.
//   unit_output_style: `.chinese` keeps unit text (二十五千克 → 25千克);
//       `.symbol` writes known units as symbols (二十五千克 → 25 kg).
//   currency_output_style: `.chinese` keeps suffix currency words
//       (一千美元 → 1000美元); `.symbol` writes currency symbols
//       (一千美元 → $1000).
//   range_output_style: `.chineseConnector` keeps 到; `.symbol` writes ~.
//       This changes only the connector, not whether endpoint digits
//       arabize.
//   spoken_range_style: `.preserve` keeps vague spoken ranges such as
//       三五百 / 十五六 verbatim; `.expand` writes normal ranges such as
//       300到500 / 15到16.
//   enable_time_english_mapping: when True, time-related Chinese spans
//       map noon prefixes to English short forms (下午三点四十五分 →
//       3:45 p.m.). Unit abbreviations are controlled by unit_output_style.
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

public enum ChineseITNUnitOutputStyle: String, Sendable, CaseIterable {
    case chinese
    case symbol
}

public enum ChineseITNCurrencyOutputStyle: String, Sendable, CaseIterable {
    case chinese
    case symbol
}

public enum ChineseITNRangeOutputStyle: String, Sendable, CaseIterable {
    case chineseConnector
    case symbol
}

public enum ChineseITNSpokenRangeStyle: String, Sendable, CaseIterable {
    case preserve
    case expand
}

public struct ChineseITNConfig: Sendable {

    public var enableStandaloneNumber: Bool
    public var enable0To9: Bool
    public var enableMillion: Bool
    public var removeInterjections: Bool
    public var enableTimeEnglishMapping: Bool
    public var unitOutputStyle: ChineseITNUnitOutputStyle
    public var currencyOutputStyle: ChineseITNCurrencyOutputStyle
    public var rangeOutputStyle: ChineseITNRangeOutputStyle
    public var spokenRangeStyle: ChineseITNSpokenRangeStyle
    public var temporalOutputStyle: ChineseITNTemporalOutputStyle

    public init(
        enableStandaloneNumber: Bool = true,
        enable0To9: Bool = false,
        enableMillion: Bool = false,
        removeInterjections: Bool = true,
        enableTimeEnglishMapping: Bool = false,
        unitOutputStyle: ChineseITNUnitOutputStyle = .chinese,
        currencyOutputStyle: ChineseITNCurrencyOutputStyle = .chinese,
        rangeOutputStyle: ChineseITNRangeOutputStyle = .chineseConnector,
        spokenRangeStyle: ChineseITNSpokenRangeStyle = .preserve,
        temporalOutputStyle: ChineseITNTemporalOutputStyle = .compactNumeric
    ) {
        self.enableStandaloneNumber = enableStandaloneNumber
        self.enable0To9 = enable0To9
        self.enableMillion = enableMillion
        self.removeInterjections = removeInterjections
        self.enableTimeEnglishMapping = enableTimeEnglishMapping
        self.unitOutputStyle = unitOutputStyle
        self.currencyOutputStyle = currencyOutputStyle
        self.rangeOutputStyle = rangeOutputStyle
        self.spokenRangeStyle = spokenRangeStyle
        self.temporalOutputStyle = temporalOutputStyle
    }

    public var rangeConnector: String {
        rangeOutputStyle == .symbol ? "~" : "到"
    }

    @available(*, deprecated, message: "Use spokenRangeStyle instead.")
    public var enableSpecialTilde: Bool {
        get { spokenRangeStyle == .expand }
        set { spokenRangeStyle = newValue ? .expand : .preserve }
    }

    @available(*, deprecated, message: "Use currencyOutputStyle instead.")
    public var enableMoneyNormalization: Bool {
        get { currencyOutputStyle == .symbol }
        set { currencyOutputStyle = newValue ? .symbol : .chinese }
    }

    /// Product default.
    public static let `default` = ChineseITNConfig()

    /// Historical fixture-diagnostic preset. The name is kept for
    /// source compatibility, but product-oriented style choices mean it
    /// is no longer a byte-for-byte WeText contract.
    public static let weTextLibraryDefault = ChineseITNConfig(
        enableStandaloneNumber: true,
        enable0To9: false,
        enableMillion: false,
        removeInterjections: true,
        enableTimeEnglishMapping: true,
        unitOutputStyle: .symbol,
        currencyOutputStyle: .symbol,
        rangeOutputStyle: .symbol,
        spokenRangeStyle: .expand
    )

    /// Historical official-corpus diagnostic preset. It keeps the old
    /// single-digit setting while using the product style model.
    public static let weTextOfficialTest = ChineseITNConfig(
        enableStandaloneNumber: true,
        enable0To9: true,
        enableMillion: false,
        removeInterjections: true,
        enableTimeEnglishMapping: true,
        unitOutputStyle: .symbol,
        currencyOutputStyle: .symbol,
        rangeOutputStyle: .symbol,
        spokenRangeStyle: .expand
    )
}
