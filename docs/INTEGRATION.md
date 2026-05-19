# Integration Guide

How to drop ChineseITN into an iOS or macOS app or another Swift package.

## Install via Swift Package Manager

Add as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/xzjh/chinese-itn-swift.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["ChineseITN"]),
]
```

Or in Xcode: File → Add Package Dependencies → paste the repo URL.

Minimum platforms: macOS 13 / iOS 16.

## Use the public API

```swift
import ChineseITN

// One-shot normalization
let result = ChineseITN.normalize("内存占用四点零八个G")
// "内存占用4.08个G"
```

`ChineseITN.normalize(_:)` is a pure function. Thread-safe. No
initialization required. Each call is roughly 30-200µs depending on
input length (regex + table lookups, no I/O).

## Recommended pipeline placement

Drop in AFTER your ASR engine and BEFORE either:
- the user-facing display (so the user sees normalized text), OR
- the next-stage NLU / LLM (so downstream code can rely on
  Arabic-numeral input).

```
audio → ASR engine → ChineseITN.normalize(...) → final
```

If your pipeline includes an "organize / cleanup LLM" stage (filler
removal, retraction handling, etc.), put ChineseITN AFTER that
stage so the LLM doesn't accidentally re-Chinesify Arabic numerals
it sees. The combined ordering is:

```
ASR → strip_punct (if used) → organize LLM → ChineseITN → paste
```

## What ChineseITN handles

| Category   | Example                                            |
| ---------- | -------------------------------------------------- |
| Cardinal   | 五十块钱 → 50块钱; 两千五百万 → 2500万             |
| Decimal    | 四点零八个G → 4.08个G                              |
| Date       | 二零二六年五月四号 → 2026年05月04日               |
| Time       | 下午三点四十五分 → 3:45p.m.                        |
| Money      | 两百欧元 → €200                                    |
| Fraction   | 百分之三十 → 30%; 三分之二 → 2/3                   |
| Telephone  | 幺三八幺幺幺零零零零零 → 13811100000               |
| Plate      | 京A幺二三四五 → 京A12345                           |
| Electronic | w w w 点 baidu 点 com → www.baidu.com              |
| Whitelist  | 百闻不如一见 → unchanged; 我说一句话 → unchanged   |

The full list of expected behaviors per category is in
`Tests/ChineseITNTests/Fixtures/parity.json` (126 fixtures).

## What it does NOT handle

- Email reconstruction from spaced spoken form ("X 艾特 Y") — Phase 4.
- Math expressions (加 / 减 / 乘 / 除).
- Most non-CJK locales (en / ja). Designed for zh.
- Punctuation restoration. (Use your ASR or organize LLM for this.)

## Test it in your project

```swift
import XCTest
@testable import MyApp
import ChineseITN

func testZhDictationDecimal() {
    let raw = "我的体重是六十五点三公斤"
    let normalized = ChineseITN.normalize(raw)
    XCTAssertEqual(normalized, "我的体重是65.3公斤")
}
```

## Performance

Measured on M1 Pro / iOS 17 Simulator:

| Input length         | Latency          |
| -------------------- | ---------------- |
| 10 chars             | ~30µs            |
| 100 chars            | ~80µs            |
| 1000 chars           | ~500µs           |

ChineseITN's overhead is negligible compared to ASR / LLM latency.
Each call allocates ~few KB of intermediate strings; no long-lived
allocation.

## Known divergences from the reference Python libraries

This port deliberately produces different output from WeText /
fun_text_processing in two cases:

1. **Date format**: We use "X年Y月Z日" (fun_text_processing style),
   not "X/Y/Z" (WeText style). Reason: more natural Chinese
   convention; matches modern Chinese writing.
2. **Bare "X点Y单位"**: We classify "四点零八G" as decimal "4.08G",
   not WeText's FST-misclassification "4:08G" (time). Reason:
   "G" is a measurement unit, decimal is the correct semantics.

Both are documented in the fixtures and code comments. Other modules
target byte-for-byte parity with their respective source library.

## Reporting issues

Open an issue at https://github.com/xzjh/chinese-itn-swift/issues
with:
- The exact Chinese input
- The expected output (what you'd hand-write)
- What ChineseITN produced
- Which reference library (WeText or fun_text_processing) you compared against, if any
