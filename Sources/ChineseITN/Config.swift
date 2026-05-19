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

import Foundation

public struct ChineseITNConfig: Sendable {

    public var enableStandaloneNumber: Bool
    public var enable0To9: Bool
    public var enableMillion: Bool
    public var removeInterjections: Bool

    public init(
        enableStandaloneNumber: Bool = true,
        enable0To9: Bool = false,
        enableMillion: Bool = false,
        removeInterjections: Bool = true
    ) {
        self.enableStandaloneNumber = enableStandaloneNumber
        self.enable0To9 = enable0To9
        self.enableMillion = enableMillion
        self.removeInterjections = removeInterjections
    }

    /// Matches WeText's `InverseNormalizer()` default constructor.
    public static let `default` = ChineseITNConfig()

    /// Matches the config used by WeText's official test suite at
    /// itn/chinese/test/normalizer_test.py — i.e. what produced the
    /// expected outputs in test/data/*.txt. Used by OfficialParityTests.
    public static let weTextOfficialTest = ChineseITNConfig(
        enableStandaloneNumber: true,
        enable0To9: true,
        enableMillion: false,
        removeInterjections: true
    )
}
