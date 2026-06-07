// chinese-itn — CLI for ChineseITN.
// Reads one input per line from stdin, writes normalized output line
// per line to stdout. Newlines inside input are NOT supported (use a
// JSONL caller to encode if needed).
//
// Flags:
//   --enable-0-to-9         Single Chinese digit chars (一..九, 零) convert
//                           standalone. Default off (WeText library default).
//   --unit-style STYLE      Unit output style: chinese or symbol.
//   --currency-style STYLE  Currency output style: chinese or symbol.
//   --range-style STYLE     Range connector style: chinese or symbol.
//   --spoken-range-style STYLE
//                           Spoken approximate range style: preserve or expand.
//   --enable-time-english   Map noon prefix (早上→a.m.). Default off.
//   --temporal-style STYLE   Date/time output style:
//                           compact, chinese-numeric, spoken-chinese.
//                           Default compact preserves legacy output.
//   --library-default       Preset matching WeText InverseNormalizer() no-arg
//                           constructor. Implies --enable-special-tilde.
//   --official-test         Preset matching WeTextProcessing's official
//                           test config: enable_0_to_9=true + special_tilde=true.
//   --no-interjections      Disable interjection (呃/啊) removal. Default
//                           removes them (WeText default).
//   --enable-million        Extend 万 prefix to thousand/hundred coefficients.
//                           Default off.
//   --enable-money          Compatibility alias for --currency-style symbol.
//
// Examples:
//   echo "内存占用四点零八个G" | chinese-itn
//   #   内存占用4.08个G
//
//   echo "一" | chinese-itn --enable-0-to-9
//   #   1

import Foundation
import ChineseITN

func parseArgs() -> ChineseITNConfig {
    var cfg = ChineseITNConfig.default
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < args.count {
        let a = args[i]
        switch a {
        case "--enable-0-to-9":
            cfg.enable0To9 = true
        case "--enable-special-tilde":
            cfg.spokenRangeStyle = .expand
            cfg.rangeOutputStyle = .symbol
        case "--enable-time-english":
            cfg.enableTimeEnglishMapping = true
            cfg.unitOutputStyle = .symbol
        case "--library-default":
            cfg = .weTextLibraryDefault
        case "--official-test":
            cfg = .weTextOfficialTest
        case "--no-interjections":
            cfg.removeInterjections = false
        case "--enable-million":
            cfg.enableMillion = true
        case "--enable-money":
            cfg.currencyOutputStyle = .symbol
        case "--disable-standalone-number":
            cfg.enableStandaloneNumber = false
        case "--unit-style":
            guard i + 1 < args.count,
                  let style = parseUnitStyle(args[i + 1]) else {
                FileHandle.standardError.write(
                    Data("chinese-itn: --unit-style expects chinese or symbol\n".utf8)
                )
                exit(2)
            }
            cfg.unitOutputStyle = style
            i += 1
        case "--currency-style":
            guard i + 1 < args.count,
                  let style = parseCurrencyStyle(args[i + 1]) else {
                FileHandle.standardError.write(
                    Data("chinese-itn: --currency-style expects chinese or symbol\n".utf8)
                )
                exit(2)
            }
            cfg.currencyOutputStyle = style
            i += 1
        case "--range-style":
            guard i + 1 < args.count,
                  let style = parseRangeStyle(args[i + 1]) else {
                FileHandle.standardError.write(
                    Data("chinese-itn: --range-style expects chinese or symbol\n".utf8)
                )
                exit(2)
            }
            cfg.rangeOutputStyle = style
            i += 1
        case "--spoken-range-style":
            guard i + 1 < args.count,
                  let style = parseSpokenRangeStyle(args[i + 1]) else {
                FileHandle.standardError.write(
                    Data("chinese-itn: --spoken-range-style expects preserve or expand\n".utf8)
                )
                exit(2)
            }
            cfg.spokenRangeStyle = style
            i += 1
        case "--temporal-style":
            guard i + 1 < args.count,
                  let style = parseTemporalStyle(args[i + 1]) else {
                FileHandle.standardError.write(
                    Data("chinese-itn: --temporal-style expects compact, chinese-numeric, or spoken-chinese\n".utf8)
                )
                exit(2)
            }
            cfg.temporalOutputStyle = style
            i += 1
        case "--help", "-h":
            print("""
            chinese-itn — Chinese Inverse Text Normalization CLI

            Usage: chinese-itn [flags] < input.txt > output.txt

            Reads one input per line from stdin; writes normalized
            output line-per-line to stdout.

            Flags:
              --enable-0-to-9            convert single 一..九, 零 standalone
              --unit-style STYLE         unit style: chinese or symbol
              --currency-style STYLE     currency style: chinese or symbol
              --range-style STYLE        range connector: chinese or symbol
              --spoken-range-style STYLE spoken ranges: preserve or expand
              --enable-special-tilde     alias: spoken-range expand + range symbol
              --enable-time-english      alias: map 早上→a.m. and unit-style symbol
              --library-default          preset matching WeText InverseNormalizer()
              --official-test            preset matching WeText official tests
              --no-interjections         keep 呃/啊 fillers
              --enable-million           千/百+万 fully arabize (vs keep 万 suffix)
              --enable-money             alias: currency-style symbol
              --disable-standalone-number  don't convert bare cardinal expressions
                                         (only convert when bound to unit/currency/etc)
              --temporal-style STYLE      date/time style: compact,
                                         chinese-numeric, spoken-chinese
              -h, --help                 show this help
            """)
            exit(0)
        default:
            FileHandle.standardError.write(
                Data("chinese-itn: unknown flag \(a)\n".utf8)
            )
            exit(2)
        }
        i += 1
    }
    return cfg
}

private func parseTemporalStyle(_ raw: String) -> ChineseITNTemporalOutputStyle? {
    switch raw {
    case "compact", "compact-numeric", "compactNumeric":
        return .compactNumeric
    case "chinese-numeric", "chineseNumeric":
        return .chineseNumeric
    case "spoken-chinese", "spokenChinese":
        return .spokenChinese
    default:
        return nil
    }
}

private func parseUnitStyle(_ raw: String) -> ChineseITNUnitOutputStyle? {
    switch raw {
    case "chinese": return .chinese
    case "symbol": return .symbol
    default: return nil
    }
}

private func parseCurrencyStyle(_ raw: String) -> ChineseITNCurrencyOutputStyle? {
    switch raw {
    case "chinese": return .chinese
    case "symbol": return .symbol
    default: return nil
    }
}

private func parseRangeStyle(_ raw: String) -> ChineseITNRangeOutputStyle? {
    switch raw {
    case "chinese", "chinese-connector", "chineseConnector":
        return .chineseConnector
    case "symbol":
        return .symbol
    default:
        return nil
    }
}

private func parseSpokenRangeStyle(_ raw: String) -> ChineseITNSpokenRangeStyle? {
    switch raw {
    case "preserve": return .preserve
    case "expand": return .expand
    default: return nil
    }
}

let config = parseArgs()

while let line = readLine(strippingNewline: true) {
    let out = ChineseITN.normalize(line, config: config)
    print(out)
}
