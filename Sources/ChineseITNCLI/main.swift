// chinese-itn — CLI for ChineseITN.
// Reads one input per line from stdin, writes normalized output line
// per line to stdout. Newlines inside input are NOT supported (use a
// JSONL caller to encode if needed).
//
// Flags:
//   --enable-0-to-9     Single Chinese digit chars (一..九, 零) convert
//                       standalone. Default off (WeText library default).
//   --official-test     Preset matching WeTextProcessing's official
//                       test config: enable_0_to_9=true.
//   --no-interjections  Disable interjection (呃/啊) removal. Default
//                       removes them (WeText default).
//   --enable-million    Extend 万 prefix to thousand/hundred coefficients.
//                       Default off.
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
    for a in args {
        switch a {
        case "--enable-0-to-9":
            cfg.enable0To9 = true
        case "--official-test":
            cfg = .weTextOfficialTest
        case "--no-interjections":
            cfg.removeInterjections = false
        case "--enable-million":
            cfg.enableMillion = true
        case "--help", "-h":
            print("""
            chinese-itn — Chinese Inverse Text Normalization CLI

            Usage: chinese-itn [flags] < input.txt > output.txt

            Reads one input per line from stdin; writes normalized
            output line-per-line to stdout.

            Flags:
              --enable-0-to-9     convert single 一..九, 零 standalone
              --official-test     preset matching WeText official tests
              --no-interjections  keep 呃/啊 fillers
              --enable-million    千万/亿万 coefficient prefix
              -h, --help          show this help
            """)
            exit(0)
        default:
            FileHandle.standardError.write(
                Data("chinese-itn: unknown flag \(a)\n".utf8)
            )
            exit(2)
        }
    }
    return cfg
}

let config = parseArgs()

while let line = readLine(strippingNewline: true) {
    let out = ChineseITN.normalize(line, config: config)
    print(out)
}
