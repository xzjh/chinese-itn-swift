// chinese-itn — CLI for ChineseITN.
// Reads one input per line from stdin, writes normalized output line
// per line to stdout. Newlines inside input are NOT supported (use a
// JSONL caller to encode if needed).
//
// Flags:
//   --enable-0-to-9         Single Chinese digit chars (一..九, 零) convert
//                           standalone. Default off (WeText library default).
//   --enable-special-tilde  Spoken approximate ranges emit tilde forms
//                           ("一二"→"1~2", "三五百"→"300~500"). Default off
//                           (our library default; WeText defaults this on).
//   --enable-time-english   Map noon prefix (早上→a.m.) and time units
//                           (分钟→min, 小时→h). Default off (kept Chinese).
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
            cfg.enableSpecialTilde = true
        case "--enable-time-english":
            cfg.enableTimeEnglishMapping = true
        case "--library-default":
            cfg = .weTextLibraryDefault
        case "--official-test":
            cfg = .weTextOfficialTest
        case "--no-interjections":
            cfg.removeInterjections = false
        case "--enable-million":
            cfg.enableMillion = true
        case "--disable-standalone-number":
            cfg.enableStandaloneNumber = false
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
              --enable-special-tilde     emit spoken-range tilde forms (一二→1~2)
              --enable-time-english      map 早上→a.m. and 分钟→min etc.
              --library-default          preset matching WeText InverseNormalizer()
              --official-test            preset matching WeText official tests
              --no-interjections         keep 呃/啊 fillers
              --enable-million           千/百+万 fully arabize (vs keep 万 suffix)
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

let config = parseArgs()

while let line = readLine(strippingNewline: true) {
    let out = ChineseITN.normalize(line, config: config)
    print(out)
}
