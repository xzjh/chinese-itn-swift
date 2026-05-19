// OfficialParityTests.swift
// Validates against WeTextProcessing's OFFICIAL test corpus (189
// cases in 12 categories, copied from
// https://github.com/wenet-e2e/WeTextProcessing/tree/master/itn/chinese/test/data ).
//
// Reports overall parity rate. The test PASSES if the parity rate
// meets the minimum threshold (currently 50% — see
// `minimumParityRate` below). Individual failures are NOT
// catastrophic — they're documented as known divergences. The point
// of this test is to track parity over time as we add module
// coverage.

import XCTest
@testable import ChineseITN

final class OfficialParityTests: XCTestCase {

    /// Minimum overall parity rate we require to pass. Conservative
    /// lower bound that prevents accidental regression. Raise as
    /// coverage grows.
    static let minimumParityRate: Double = 0.50

    static var fixtures: [Fixture] = {
        guard let url = Bundle.module.url(forResource: "Fixtures/parity_official",
                                          withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Fixture].self, from: data)
        } catch {
            return []
        }
    }()

    func testOfficialCorpusLoaded() {
        XCTAssertGreaterThan(Self.fixtures.count, 100,
                             "Official corpus should have 100+ cases")
    }

    func testOfficialCorpusParityRate() {
        guard !Self.fixtures.isEmpty else {
            XCTFail("No official fixtures loaded")
            return
        }
        var pass = 0
        var byCategory: [String: (pass: Int, fail: Int)] = [:]
        for fx in Self.fixtures {
            let actual = ChineseITN.normalize(fx.input)
            let isPass = actual == fx.expected
            if isPass { pass += 1 }
            var bc = byCategory[fx.category] ?? (0, 0)
            if isPass { bc.pass += 1 } else { bc.fail += 1 }
            byCategory[fx.category] = bc
        }
        let total = Self.fixtures.count
        let rate = Double(pass) / Double(total)

        // Print per-category breakdown — visible in xcodebuild output.
        let lines = byCategory
            .sorted(by: { $0.key < $1.key })
            .map { (cat, counts) in
                let pct = Double(counts.pass) / Double(counts.pass + counts.fail) * 100
                return "  [\(cat)] \(counts.pass)/\(counts.pass + counts.fail) (\(String(format: "%.0f", pct))%)"
            }
            .joined(separator: "\n")
        let report = """

        Official WeText parity: \(pass)/\(total) = \(String(format: "%.1f", rate * 100))%
        \(lines)

        """
        print(report)

        XCTAssertGreaterThanOrEqual(rate, Self.minimumParityRate,
            "Parity rate \(rate * 100)% below minimum \(Self.minimumParityRate * 100)%")
    }
}
