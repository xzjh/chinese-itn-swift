# ChineseITN

Pure-Swift Chinese Inverse Text Normalization (ITN) — converts the
spoken-form Chinese that ASR systems emit into written form.

纯Swift实现的中文ITN（口语形态→书面形态）。无运行时FST依赖，可
直接嵌入macOS / iOS App。

| Spoken / 口语                | →   | Written / 书面             |
| --------------------------- | --- | ------------------------ |
| 二零二六年五月四号             | →   | 2026/05/04               |
| 下午三点四十五分                | →   | 下午3:45                  |
| 三点半                        | →   | 3:30                     |
| 内存占用四点零八个G              | →   | 内存占用4.08个G           |
| 百分之三十                     | →   | 30%                      |
| 百分之三十到四十一               | →   | 30%到41%                 |
| 两千五百万                     | →   | 2500万                   |
| 三亿五千万                     | →   | 3亿5000万                |
| 一千美元                      | →   | 1000美元                 |
| 重达二十五千克                  | →   | 重达25千克               |
| 幺三八幺幺幺零零零零零            | →   | 13811100000              |
| 京A幺二三四五                  | →   | 京A12345                  |
| 一加二等于三                    | →   | 1+2=3                    |
| 二到四万                      | →   | 二到四万                 |
| 三五百                        | →   | 三五百                   |
| 十五六                        | →   | 十五六                   |
| 二分之一                       | →   | 1/2                      |
| 负三点一四                     | →   | -3.14                    |
| 我的身份证号是三四零二零三一九三七零幺零幺零五幺七 | → | 我的身份证号是340203193701010517 |
| w w w 点 baidu 点 com         | →   | www.baidu.com            |
| 百闻不如一见                   | →   | 百闻不如一见（保留成语）     |

---

## English

### Why this library

Chinese ASR systems (Whisper, Qwen3-ASR, SenseVoice, etc.) produce
spoken-form transcripts (一千 instead of 1000). Downstream tools
typically expect written form. The conversion is hard because
context disambiguates between time (三点四十五分 = 3:45) and decimal
(三点四五 = 3.45), idioms must be preserved (一帆风顺), and
multi-segment cardinals follow specific rules (两千五百万 keeps the
万 suffix).

Reference Python libraries (WeTextProcessing, fun_text_processing)
solve this with Pynini-compiled FSTs — which requires OpenFst C++
and can't ship in an iOS bundle. This library reimplements the same
grammars in pure Swift, no native dependency.

### Install

Swift Package Manager:

```swift
.package(url: "https://github.com/xzjh/chinese-itn-swift", from: "0.3.0")
```

Add `"ChineseITN"` as a target dependency.

### Use

```swift
import ChineseITN

let out = ChineseITN.normalize("内存占用四点零八个G")
// "内存占用4.08个G"
```

The API is a single static method. Threading-safe (all state is
immutable lookup tables); call from any queue.

### Configuration

`ChineseITN.normalize(_:config:)` takes an optional `ChineseITNConfig`.
The default is product-oriented: Chinese units and currency names stay
Chinese, ranges keep the spoken `到` connector, and vague spoken ranges
such as `三五百` / `十五六` are preserved unless explicitly expanded.

| Option | Default | Effect |
|------|---------|--------|
| `enableStandaloneNumber` | `true` | `false` keeps bare cardinal expressions in Chinese (`两万` → `两万`). Anchored forms such as decimals, dates, percentages, units, and currency still normalize. |
| `enable0To9` | `false` | `true` converts standalone single Chinese digits and single-digit range endpoints (`一` → `1`, `二到四万` → `2到4万`). |
| `enableMillion` | `false` | `true` fully arabizes 千/百 + 万 (`两千五百万` → `25000000`) instead of keeping `万` as a readability marker (`2500万`). |
| `removeInterjections` | `true` | `false` keeps `呃` / `啊` fillers. |
| `unitOutputStyle` | `.chinese` | `.symbol` writes known units as symbols (`二千克` → `2 kg`, `二十分钟` → `20 min`). Default keeps Chinese unit text (`二千克`, `20分钟`). |
| `currencyOutputStyle` | `.chinese` | `.symbol` writes currency symbols (`一千美元` → `$1000`, `三千三百八十元五角八分` → `¥3380.58`). Default keeps suffix currency words (`1000美元`). |
| `rangeOutputStyle` | `.chineseConnector` | `.symbol` changes only the range connector (`二到四万` → `二~四万`). Digit conversion is still controlled by `enable0To9`, unit style, or currency style. |
| `spokenRangeStyle` | `.preserve` | `.expand` expands vague spoken ranges (`三五百` → `300到500`, `十五六` → `15到16`). The connector follows `rangeOutputStyle`. |
| `enableTimeEnglishMapping` | `false` | `true` maps noon-prefix words to a.m./p.m. (`下午三点四十五分` → `3:45 p.m.`). Unit abbreviations are controlled by `unitOutputStyle`. |
| `temporalOutputStyle` | `.compactNumeric` | `.chineseNumeric` keeps Chinese date/time units with Arabic digits (`5月10号`, `5点31分`); `.spokenChinese` preserves matched date/time spans verbatim. |

The historical `weTextLibraryDefault` / `weTextOfficialTest` preset names
are still present for fixture diagnostics, but product behavior is no
longer defined by byte-for-byte WeText output.

```swift
var cfg = ChineseITNConfig.default
cfg.enableMillion = true
ChineseITN.normalize("两千五百万美元", config: cfg)
// "25000000美元"

cfg.currencyOutputStyle = .symbol
ChineseITN.normalize("一千美元", config: cfg)
// "$1000"

cfg.unitOutputStyle = .symbol
ChineseITN.normalize("二到四千克", config: cfg)
// "2到4 kg"

cfg.temporalOutputStyle = .chineseNumeric
ChineseITN.normalize("五月十号五点三十一分", config: cfg)
// "5月10号 5点31分"
```

CLI equivalents (in the `chinese-itn` executable):

```
chinese-itn --enable-0-to-9               # enable0To9 = true
chinese-itn --unit-style symbol           # unitOutputStyle = .symbol
chinese-itn --currency-style symbol       # currencyOutputStyle = .symbol
chinese-itn --range-style symbol          # rangeOutputStyle = .symbol
chinese-itn --spoken-range-style expand   # spokenRangeStyle = .expand
chinese-itn --enable-time-english         # enableTimeEnglishMapping = true
chinese-itn --enable-million              # enableMillion = true
chinese-itn --enable-money                # compatibility alias for currency-style symbol
chinese-itn --enable-special-tilde        # compatibility alias for spoken-range expand + range symbol
chinese-itn --disable-standalone-number   # enableStandaloneNumber = false
chinese-itn --temporal-style chinese-numeric
chinese-itn --no-interjections            # removeInterjections = false
chinese-itn --library-default             # use the weTextLibraryDefault preset
chinese-itn --official-test               # use the weTextOfficialTest preset
```

### Supported categories

| Module          | What it handles                                                 |
| --------------- | --------------------------------------------------------------- |
| Cardinal        | 一 / 十 / 百 / 千 / 万 / 亿 positional read; multi-segment kept (两千五百万 → 2500万, 三亿五千万 → 3亿5000万); pure-digit reads for 11-digit mobile, 18-digit ID card, 14–16 with 3–5 char prefix split (e.g. 加一二三四 + 11-digit) |
| Decimal         | X点Y → X.Y, with optional 负 sign; symmetric X杠Y → X-Y for identifier / range pattern (三杠二十三 → 3-23, 一杠二 → 1-2) |
| Date            | 年月日 → YYYY/MM/DD; 年月 → YYYY/MM; 月日 → MM/DD; standalone 年 kept (二零零八年 → 2008年); 公元X年 → 公元 + arabized year |
| Time            | X点Y分 → HH:MM, X点Y分Z秒 → HH:MM:SS, X点半 → HH:30, noon prefix (上午/早上/早晨 → a.m., 下午/晚上/傍晚 → p.m.) |
| Money           | 元 / 美元 / 欧元 / 英镑 / 港元 / 日元 etc.; default keeps currency words as suffix units (`一千美元` → `1000美元`), while `currencyOutputStyle = .symbol` emits symbols (`$1000`, `¥3380.58`) |
| Fraction        | X分之Y → Y/X (multi-char numerator and denominator); 百分(之)?X → X%; 百分百 → 100%; 百分之X点Y → X.Y%; 百分之X到Y follows `rangeOutputStyle` (`30%到41%` or `30%~41%`) |
| Measure         | cardinal / decimal + unit; default keeps Chinese unit text (`二十五千克` → `25千克`), while `unitOutputStyle = .symbol` emits SI / English symbols with spacing (`25 kg`, `10 km`, `20 min`) |
| Math            | 加 / 减 / 乘 / 除 / 比 / 等于 → + − × ÷ : =, with chained 负 sign; 到 is treated as a range connector controlled by `rangeOutputStyle` |
| LicensePlate    | 京A幺二三四五 → 京A12345 (31 province chars + alpha + 5–6 char body) |
| Electronic      | spaced URL "w w w 点 X 点 Y" → www.X.Y                          |
| SpecialCardinal | vague spoken ranges; default preserves (`三五百`, `十五六`), while `spokenRangeStyle = .expand` outputs normal ranges (`300到500`, `15到16`, or `300~500`, `15~16` with symbol range style) |
| Whitelist       | 130+ idioms / fixed phrases protected from any digit conversion (一帆风顺, 百闻不如一见, 三心二意, 乱七八糟, 十几万, 三亚, 九寨沟, 星期一/二/三/..., 二维码, ...) including the 几X approximate-quantifier family (几十/几百/几千/几万/几亿/几十亿/...) — kept verbatim to avoid WeText's half-converted "几10" output |

Architecture: every module is a "tagger" that emits weighted
candidate edges over the input. A topological-DP shortest-path
solver picks the lowest-cost coverage. Tagger weights mirror
WeText's FST add_weight() values (LicensePlate 1.0 → Date 1.02 →
Money 1.04 → Fraction/Measure/Time 1.05 → Cardinal 1.06 →
Math 1.10 → Char fallback 100), so disambiguation between
overlapping matches happens globally on cost — not via local
heuristics or fixed pipeline order.

### Design — combined from two reference libraries

This port draws algorithm and data from two Pynini-based references:

- WeTextProcessing (Apache 2.0) by the WeNet community — primary
  base. Cardinal, Decimal, Date, Time, Money, Fraction, Measure,
  LicensePlate, Math, Whitelist all follow WeText grammars and
  reproduce its TSV lookup tables byte-for-byte.
- fun_text_processing (MIT) by Alibaba DAMO — adopted for the
  Electronic (URL) module, which WeText doesn't cover.

WeText's Pynini FST composition is reimplemented in Swift as a
weighted token-graph (lattice) with shortest-path selection.
No native dependency — pure Swift on macOS / iOS.

### Test coverage

Three test layers, all passing:

- Product contract tests: explicit assertions for every public option
  (`enable0To9`, unit style, currency style, range style, spoken range
  style, temporal style, interjection removal, and core false-positive
  protection).
- WeText official 189-case corpus: still loaded as a diagnostic parity
  benchmark. Current product-style output is 168/189 = 88.9% against
  the original WeText byte-for-byte fixture target, and the test asserts
  a minimum regression floor rather than exact parity.
- Robustness corpus: 285 hand-curated inputs across 19 true-positive
  categories and 6 false-positive categories. Current product-style
  output is 276/285 = 96.8%.
- ParityTests: 126 hand-crafted fixtures with `expected_swift`
  overrides where product output intentionally diverges from WeText;
  current pass rate is 126/126.

In total: 600 fixture cases plus explicit XCTest methods across the
module, product configuration, range, temporal, and false-positive
test files.

How this compares to the reference libraries:

| Test asset             | ChineseITN-swift | WeTextProcessing | fun_text_processing (zh) |
| ---------------------- | ---------------- | ---------------- | ------------------------ |
| Official fixtures      | 600              | 189 unique       | 0 (zh has no test corpus; only ja / id are provided) |
| False-positive cases   | 78               | 0                | 0                        |
| Categories covered     | 19 TP + 6 FP     | 12               | —                        |
| Per-method assertions  | product contract + module tests | — | — |

Our suite is a superset of WeText's: we vendor their 189 official
cases verbatim, then add 411 more curated cases (the robustness
corpus plus hand-crafted parity fixtures). The robustness corpus is
the only piece neither reference library has — false-positive
guards (idiom preservation, plain text, ambiguous-`一`, `点` not as
decimal, `年` not as date) protect against regressions that have no
analog in the reference Python suites.

Run with:

```bash
swift test
```

Fixtures are generated from the live reference Python libraries via
scripts/generate_fixtures.py and scripts/generate_robustness_fixtures.py.

### License

Apache License 2.0. See LICENSE. Third-party attribution in NOTICE.

### Author

xzjh

---

## 中文

### 为什么需要这个库

中文ASR系统（Whisper / Qwen3-ASR / SenseVoice等）输出的是口语形态
文本（"一千"而不是"1000"），但下游消费方通常期望书面形态。这个
转换并不简单：上下文决定了"三点四十五分"是时间（3:45）而"三点
四五"是小数（3.45）；成语必须保护（"一帆风顺"不能变成"1帆风顺"）；
多段位数字遵循特定写法（"两千五百万"保留万后缀写成"2500万"）。

业界Python参考实现（WeTextProcessing、fun_text_processing）都基于
Pynini编译的FST，依赖OpenFst（C++），无法打包进iOS。本库用纯
Swift重写同一套语法，零原生依赖。

### 安装

通过Swift Package Manager：

```swift
.package(url: "https://github.com/xzjh/chinese-itn-swift", from: "0.3.0")
```

把"ChineseITN"加入target依赖。

### 使用

```swift
import ChineseITN

let out = ChineseITN.normalize("内存占用四点零八个G")
// "内存占用4.08个G"
```

公共API就一个静态方法。线程安全（所有状态都是不可变查表），可从
任何队列调用。

### 配置

`ChineseITN.normalize(_:config:)` 接受可选的 `ChineseITNConfig`。
默认值面向产品输出：单位和货币默认保留中文，范围默认保留`到`，
`三五百`、`十五六`这类口语估数默认保留原文，只有显式开启才展开。

| 选项 | 默认 | 效果 |
|------|------|------|
| `enableStandaloneNumber` | `true` | `false`时纯cardinal表达式保留中文（`两万` → `两万`）。小数、日期、百分比、单位、货币等有锚点的形式仍会整理。 |
| `enable0To9` | `false` | `true`时单字数字和单字范围端点转阿拉伯数字（`一` → `1`，`二到四万` → `2到4万`）。 |
| `enableMillion` | `false` | `true`时千/百 + 万完全展开（`两千五百万` → `25000000`），默认保留`万`作为可读性标记（`2500万`）。 |
| `removeInterjections` | `true` | `false`时保留`呃` / `啊`等filler。 |
| `unitOutputStyle` | `.chinese` | `.symbol`时单位输出符号（`二千克` → `2 kg`，`二十分钟` → `20 min`）。默认保留中文单位（`二千克`，`20分钟`）。 |
| `currencyOutputStyle` | `.chinese` | `.symbol`时货币输出符号（`一千美元` → `$1000`，`三千三百八十元五角八分` → `¥3380.58`）。默认保留中文货币词后缀（`1000美元`）。 |
| `rangeOutputStyle` | `.chineseConnector` | `.symbol`只改变范围连接符（`二到四万` → `二~四万`）。端点数字是否转阿拉伯仍由`enable0To9`、单位风格或货币风格决定。 |
| `spokenRangeStyle` | `.preserve` | `.expand`时展开口语估数范围（`三五百` → `300到500`，`十五六` → `15到16`）。连接符跟随`rangeOutputStyle`。 |
| `enableTimeEnglishMapping` | `false` | `true`时时段词转a.m./p.m.（`下午三点四十五分` → `3:45 p.m.`）。时间单位缩写由`unitOutputStyle`控制。 |
| `temporalOutputStyle` | `.compactNumeric` | `.chineseNumeric`保留中文日期/时间单位并使用阿拉伯数字（`5月10号`，`5点31分`）；`.spokenChinese`保留匹配到的日期/时间原文。 |

历史上的`weTextLibraryDefault` / `weTextOfficialTest` preset名称仍保留，
用于fixture诊断和统计，但产品行为不再以WeText逐字节输出为准。

```swift
var cfg = ChineseITNConfig.default
cfg.enableMillion = true
ChineseITN.normalize("两千五百万美元", config: cfg)
// "25000000美元"

cfg.currencyOutputStyle = .symbol
ChineseITN.normalize("一千美元", config: cfg)
// "$1000"

cfg.unitOutputStyle = .symbol
ChineseITN.normalize("二到四千克", config: cfg)
// "2到4 kg"

cfg.temporalOutputStyle = .chineseNumeric
ChineseITN.normalize("五月十号五点三十一分", config: cfg)
// "5月10号 5点31分"
```

CLI对应flag（`chinese-itn`可执行文件）：

```
chinese-itn --enable-0-to-9               # enable0To9 = true
chinese-itn --unit-style symbol           # unitOutputStyle = .symbol
chinese-itn --currency-style symbol       # currencyOutputStyle = .symbol
chinese-itn --range-style symbol          # rangeOutputStyle = .symbol
chinese-itn --spoken-range-style expand   # spokenRangeStyle = .expand
chinese-itn --enable-time-english         # enableTimeEnglishMapping = true
chinese-itn --enable-million              # enableMillion = true
chinese-itn --enable-money                # currency-style symbol的兼容别名
chinese-itn --enable-special-tilde        # spoken-range expand + range symbol的兼容别名
chinese-itn --disable-standalone-number   # enableStandaloneNumber = false
chinese-itn --temporal-style chinese-numeric
chinese-itn --no-interjections            # removeInterjections = false
chinese-itn --library-default             # 用weTextLibraryDefault preset
chinese-itn --official-test               # 用weTextOfficialTest preset
```

### 支持的类别

| 模块             | 处理范围                                                       |
| --------------- | ------------------------------------------------------------ |
| Cardinal        | 一 / 十 / 百 / 千 / 万 / 亿 位读法；多段保留万/亿（两千五百万 → 2500万，三亿五千万 → 3亿5000万）；纯数字串处理11位手机号、18位身份证、14–16位带3–5字符前缀切分（如"加一二三四"+11位号码） |
| Decimal         | X点Y → X.Y，可选"负"号；对称的X杠Y → X-Y identifier/range形态（三杠二十三 → 3-23，一杠二 → 1-2） |
| Date            | 年月日 → YYYY/MM/DD；年月 → YYYY/MM；月日 → MM/DD；独立"年"保留（二零零八年 → 2008年）；公元X年 → 公元 + 阿拉伯数字 |
| Time            | X点Y分 → HH:MM，X点Y分Z秒 → HH:MM:SS，X点半 → HH:30，上下午前缀（上午/早上/早晨 → a.m.，下午/晚上/傍晚 → p.m.） |
| Money           | 元 / 美元 / 欧元 / 英镑 / 港元 / 日元等；默认保留中文货币词后缀（`一千美元` → `1000美元`），`currencyOutputStyle = .symbol`时输出符号（`$1000`，`¥3380.58`） |
| Fraction        | X分之Y → Y/X（分子分母可多字符）；百分(之)?X → X%；百分百 → 100%；百分之X点Y → X.Y%；百分之X到Y跟随`rangeOutputStyle`（`30%到41%`或`30%~41%`） |
| Measure         | 数字 + 单位；默认保留中文单位（`二十五千克` → `25千克`），`unitOutputStyle = .symbol`时输出SI/英文符号并留空格（`25 kg`，`10 km`，`20 min`） |
| Math            | 加 / 减 / 乘 / 除 / 比 / 等于 → + − × ÷ : =，支持链式"负"号；到按范围连接符处理，由`rangeOutputStyle`控制 |
| LicensePlate    | 京A幺二三四五 → 京A12345（31个省份字符 + 字母 + 5–6字符车号） |
| Electronic      | 空格分隔URL "w w w 点 X 点 Y" → www.X.Y                       |
| SpecialCardinal | 口语估数范围；默认保留原文（`三五百`，`十五六`），`spokenRangeStyle = .expand`时输出正常范围（`300到500`，`15到16`；符号范围风格下为`300~500`，`15~16`） |
| Whitelist       | 130+条成语 / 固定搭配保护，不做任何数字转换（一帆风顺、百闻不如一见、三心二意、乱七八糟、十几万、三亚、九寨沟、星期一/二/三/...、二维码等），包含几X估数家族（几十/几百/几千/几万/几亿/几十亿/...）—— 避免WeText的"几10"半成品输出 |

架构：每个模块是一个 tagger，扫描输入并发出带权重的candidate
边。一个 topological-DP shortest-path solver 选出总成本最低的
覆盖。Tagger权重按WeText FST add_weight()值设置（LicensePlate
1.0 → Date 1.02 → Money 1.04 → Fraction/Measure/Time 1.05 →
Cardinal 1.06 → Math 1.10 → Char fallback 100），所以重叠匹配
的消歧靠全局成本竞争，不靠局部heuristic或固定pipeline顺序。

### 设计：两个参考库的取长补短

算法和数据来自两个基于Pynini的Python参考实现：

- WeTextProcessing（Apache 2.0），WeNet社区维护——主要参考。
  Cardinal / Decimal / Date / Time / Money / Fraction / Measure /
  LicensePlate / Math / Whitelist都按WeText的语法重写，TSV查表
  数据逐字复刻。
- fun_text_processing（MIT），阿里DAMO维护——Electronic（URL）
  模块来自这里，WeText不覆盖此类。

WeText的Pynini FST composition在Swift里用weighted token-graph
（lattice）+ shortest-path重写。零原生依赖，纯Swift跑在macOS /
iOS。

### 测试覆盖

三层测试，全部通过：

- 产品契约测试：显式覆盖每个公开选项（`enable0To9`、单位风格、
  货币风格、范围风格、口语估数范围风格、时间风格、填充词删除和
  核心false positive保护）。
- WeText官方189条测试集：仍作为诊断性parity benchmark加载。当前
  产品风格输出对原始WeText逐字节fixture的命中率为168/189 = 88.9%，
  测试断言最低回归阈值，不再要求完全一致。
- Robustness测试集：手工挑选285条输入，覆盖19个true positive类别
  和6个false positive类别。当前产品风格输出为276/285 = 96.8%。
- ParityTests：手写126条fixture；产品有意和WeText不同的地方用
  `expected_swift`记录，当前126/126通过。

合计：600条fixture，加上模块、产品配置、范围、时间和false positive
相关的显式XCTest方法。

与两个参考库的对比：

| 测试资源              | ChineseITN-swift | WeTextProcessing | fun_text_processing (zh) |
| -------------------- | ---------------- | ---------------- | ------------------------ |
| 官方fixture条数       | 600              | 189（去重后）     | 0（zh无测试集，仅日语 / 印尼语提供） |
| False positive用例    | 78               | 0                | 0                        |
| 覆盖类别              | 19类TP + 6类FP   | 12类             | —                        |
| 单元test method数     | 产品契约 + 模块测试 | —                | —                        |

测试集仍保留WeText官方fixture作为参照，同时增加了产品契约和
false positive保护。robustness集覆盖了参考Python实现里没有的
回归场景，例如成语保留、纯中文、歧义"一"+字符、"点"非小数、
"年"非日期等。

运行：

```bash
swift test
```

测试fixture通过scripts/generate_fixtures.py和
scripts/generate_robustness_fixtures.py用真实的Python参考库
现场生成。

### 许可证

Apache License 2.0，详见LICENSE。第三方归属见NOTICE。

### 作者

xzjh
