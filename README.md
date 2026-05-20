# ChineseITN

Pure-Swift Chinese Inverse Text Normalization (ITN) — converts the
spoken-form Chinese that ASR systems emit into written form.

纯Swift实现的中文ITN（口语形态→书面形态）。无运行时FST依赖，可
直接嵌入macOS / iOS App。

| Spoken / 口语                | →   | Written / 书面             |
| --------------------------- | --- | ------------------------ |
| 二零二六年五月四号             | →   | 2026/05/04               |
| 下午三点四十五分                | →   | 3:45p.m.                 |
| 三点半                        | →   | 3:30                     |
| 内存占用四点零八个G              | →   | 内存占用4.08个G           |
| 百分之三十                     | →   | 30%                      |
| 百分之三十到四十一               | →   | 30~41%                   |
| 两千五百万                     | →   | 2500万                   |
| 三亿五千万                     | →   | 3亿5000万                |
| 一千美元                      | →   | $1000                    |
| 重达二十五千克                  | →   | 重达25 kg                |
| 幺三八幺幺幺零零零零零            | →   | 13811100000              |
| 京A幺二三四五                  | →   | 京A12345                  |
| 一加二等于三                    | →   | 1+2=3                    |
| 三五百                        | →   | 300~500                  |
| 十五六                        | →   | 15-6                     |
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
.package(url: "https://github.com/xzjh/chinese-itn-swift", from: "0.1.0")
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
Most flags mirror WeTextProcessing's `InverseNormalizer()` parameters
with identical names and semantics. `enableSpecialTilde` diverges
from WeText library default (False here vs True upstream).

| Flag | Default | Effect when set to the non-default |
|------|---------|------------------------------------|
| `enableStandaloneNumber` | `true` | `false` → bare cardinal expressions stay in Chinese (`两万` → `两万`). Unit-bound numbers still convert (`一千克` → `1000 g`). Drops the Cardinal tagger from the lattice. |
| `enable0To9` | `false` | `true` → single Chinese digit chars convert standalone (`一` → `1`, `零` → `0`). Default keeps them Chinese to avoid spurious conversion of `一个 / 一会` etc. |
| `enableMillion` | `false` | `true` → 千/百 + 万 fully arabize (`两千五百万` → `25000000`) instead of keeping `万` as a readability marker (`两千五百万` → `2500万`). `亿` is still kept as a text marker regardless. |
| `removeInterjections` | `true` | `false` → `呃` / `啊` fillers stay in the output. Default removes them per WeText `data/default/blacklist.tsv`. |
| `enableSpecialTilde` | `false` | `true` → spoken approximate ranges emit tilde forms (`一二` → `1~2`, `三五百` → `300~500`, `三四万` → `3~4万`). Default keeps the pure-digit pair forms Chinese so a downstream LLM can decide. WeText library defaults this to True; we default to False. |
| `enableTimeEnglishMapping` | `false` | `true` → noon-prefix words map to a.m./p.m. (`早上十点半` → `10:30 a.m.`) and time units map to English abbreviations (`二十分钟` → `20 min`, `两个小时` → `2 h`, `一百毫秒` → `100 ms`). Default keeps both Chinese (`早上10:30`, `20分钟`). Other unit mappings (`千克`→kg, `公里`→km) are unaffected. A space separates value and English unit symbol per SI / NIST SP 811 / ISO 80000-1 (exception: bare `°` stays glued, e.g. `30°`); WeText emits no space. WeText library defaults this to True; we default to False. |

Three presets:
- `ChineseITNConfig.default` — recommended for real ASR post-processing where a downstream LLM handles range / approximate-quantifier interpretation. Diverges from WeText library defaults only on `enableSpecialTilde` (False here vs True upstream).
- `ChineseITNConfig.weTextLibraryDefault` — matches WeText `InverseNormalizer()` no-arg constructor exactly (all flags including `enableSpecialTilde=true`). Use this when validating against fixtures generated from the upstream library.
- `ChineseITNConfig.weTextOfficialTest` — matches the config WeText uses to run its own `test/data/*.txt` corpus (`enableStandaloneNumber=true, enable0To9=true, enableSpecialTilde=true`). Use this to reproduce WeText official-corpus numbers byte-for-byte.

```swift
var cfg = ChineseITNConfig.default
cfg.enableMillion = true
ChineseITN.normalize("两千五百万美元", config: cfg)
// "$25000000"
```

CLI equivalents (in the `chinese-itn` executable):

```
chinese-itn --enable-0-to-9               # enable0To9 = true
chinese-itn --enable-special-tilde        # enableSpecialTilde = true
chinese-itn --enable-time-english         # enableTimeEnglishMapping = true
chinese-itn --enable-million              # enableMillion = true
chinese-itn --disable-standalone-number   # enableStandaloneNumber = false
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
| Money           | 元 / 美元 / 欧元 / 英镑 / 港元 / 日元 etc. → symbol or code prefix (¥ $ € £ HKD JPY ...) |
| Fraction        | X分之Y → Y/X (multi-char numerator and denominator); 百分(之)?X → X%; 百分百 → 100%; 百分之X点Y → X.Y%; 百分之X到Y → X~Y% |
| Measure         | cardinal / decimal + unit → SI abbreviation (千克 → kg, 公里 → km, 平方米 → m², 摄氏度 → °C, 毫秒 → ms, ~85 mappings) with a space between value and symbol per SI / NIST SP 811 / ISO 80000-1 (bare `°` excepted); two-pass to prefer multi-char units (二十五千克 → 25 kg, not 25000 g) |
| Math            | 加 / 减 / 乘 / 除 / 比 / 到 / 等于 → + − × ÷ : ~ =, with chained 负 sign |
| LicensePlate    | 京A幺二三四五 → 京A12345 (31 province chars + alpha + 5–6 char body) |
| Electronic      | spaced URL "w w w 点 X 点 Y" → www.X.Y                          |
| SpecialCardinal | special_tilde ranges (三五百 → 300~500, 五六十 → 50~60, 三四万 → 3~4万); special_dash ranges (十五六 → 15-6, 四十五六 → 45-6, 七百三四十 → 730-40, 一万六七 → 16000-7000) |
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

- WeText official 189-case corpus (cardinal / date / time / money /
  measure / fraction / math / license_plate / whitelist / char /
  number / normalizer): 189/189 = 100% byte-for-byte parity.
- Robustness corpus: 285 hand-curated inputs across 19 true-positive
  categories (cardinal small/hundreds/thousands/wan-yi/pure-digit,
  decimal, date, time, money, measure basic/range, fraction, math,
  license plate, phone, special_tilde, special_dash, mixed sentences)
  and 6 false-positive categories (78 inputs covering whitelist
  idioms, plain text, ambiguous 一+char, 点 not as decimal, 年 not as
  date, idiom-embedded sentences). Currently 100% pass.
- ParityTests: hand-crafted byte-for-byte parity fixtures (126
  cases): 100% pass.

In total: 600 fixture cases + 74 explicit test methods across
5 test files.

How this compares to the reference libraries:

| Test asset             | ChineseITN-swift | WeTextProcessing | fun_text_processing (zh) |
| ---------------------- | ---------------- | ---------------- | ------------------------ |
| Official fixtures      | 600              | 189 unique       | 0 (zh has no test corpus; only ja / id are provided) |
| False-positive cases   | 78               | 0                | 0                        |
| Categories covered     | 19 TP + 6 FP     | 12               | —                        |
| Per-method assertions  | 74               | —                | —                        |

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
.package(url: "https://github.com/xzjh/chinese-itn-swift", from: "0.1.0")
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
大部分flag跟WeTextProcessing的`InverseNormalizer()`参数同名同语义。
`enableSpecialTilde`是本库特有flag（默认False；WeText默认True）。

| Flag | 默认 | 非默认时的效果 |
|------|------|----------------|
| `enableStandaloneNumber` | `true` | `false` → 纯cardinal表达式保留中文（`两万` → `两万`）。带单位的数字依然转换（`一千克` → `1000 g`）。Cardinal tagger 从lattice中移除。 |
| `enable0To9` | `false` | `true` → 单字数字standalone转阿拉伯（`一` → `1`，`零` → `0`）。默认保留中文，避免`一个 / 一会`等误转。 |
| `enableMillion` | `false` | `true` → 千/百 + 万 完全展开（`两千五百万` → `25000000`），不保留`万`作为readability标记。`亿`始终保留为文本标记。 |
| `removeInterjections` | `true` | `false` → 保留`呃` / `啊`等filler。默认删除（按WeText `data/default/blacklist.tsv`）。 |
| `enableSpecialTilde` | `false` | `true` → 口语近似范围emit波浪号形态（`一二` → `1~2`，`三五百` → `300~500`，`三四万` → `3~4万`）。默认保留纯数字对的中文形态，让下游LLM自己决定区间表达。WeText库默认为True，本库默认False。 |
| `enableTimeEnglishMapping` | `false` | `true` → 时段词转a.m./p.m.（`早上十点半` → `10:30 a.m.`），时间单位转英文缩写（`二十分钟` → `20 min`，`两个小时` → `2 h`，`一百毫秒` → `100 ms`）。默认两者都保留中文（`早上10:30`，`20分钟`）。其他单位（`千克`→kg、`公里`→km）不受影响。按 SI / NIST SP 811 / ISO 80000-1，数字和英文单位之间留一个空格（裸 `°` 例外，例 `30°`）；WeText 不留空格。WeText库默认为True，本库默认False。 |

三个preset：
- `ChineseITNConfig.default` —— 推荐用于真实ASR后处理（下游有LLM处理范围/估数解读）。仅在`enableSpecialTilde`上与WeText库默认值不同（本库False，上游True）。
- `ChineseITNConfig.weTextLibraryDefault` —— 跟WeText `InverseNormalizer()`无参构造完全一致（含`enableSpecialTilde=true`）。当需要对照上游库生成的fixture验证时使用。
- `ChineseITNConfig.weTextOfficialTest` —— 跟WeText跑自己`test/data/*.txt`官方corpus用的config一致（`enableStandaloneNumber=true, enable0To9=true, enableSpecialTilde=true`）。复现WeText官方测试集逐字节parity时用这个。

```swift
var cfg = ChineseITNConfig.default
cfg.enableMillion = true
ChineseITN.normalize("两千五百万美元", config: cfg)
// "$25000000"
```

CLI对应flag（`chinese-itn`可执行文件）：

```
chinese-itn --enable-0-to-9               # enable0To9 = true
chinese-itn --enable-special-tilde        # enableSpecialTilde = true
chinese-itn --enable-time-english         # enableTimeEnglishMapping = true
chinese-itn --enable-million              # enableMillion = true
chinese-itn --disable-standalone-number   # enableStandaloneNumber = false
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
| Money           | 元 / 美元 / 欧元 / 英镑 / 港元 / 日元等 → 符号或代码前缀（¥ $ € £ HKD JPY ...） |
| Fraction        | X分之Y → Y/X（分子分母可多字符）；百分(之)?X → X%；百分百 → 100%；百分之X点Y → X.Y%；百分之X到Y → X~Y% |
| Measure         | 数字 + 单位 → 国际单位缩写（千克 → kg，公里 → km，平方米 → m²，摄氏度 → °C，毫秒 → ms，共约85条映射），按 SI / NIST SP 811 / ISO 80000-1 在数字和英文单位之间留一个空格（裸 `°` 例外）；两遍扫描优先匹配多字符单位（二十五千克 → 25 kg，不是25000 g） |
| Math            | 加 / 减 / 乘 / 除 / 比 / 到 / 等于 → + − × ÷ : ~ =，支持链式"负"号 |
| LicensePlate    | 京A幺二三四五 → 京A12345（31个省份字符 + 字母 + 5–6字符车号） |
| Electronic      | 空格分隔URL "w w w 点 X 点 Y" → www.X.Y                       |
| SpecialCardinal | special_tilde范围（三五百 → 300~500，五六十 → 50~60，三四万 → 3~4万）；special_dash范围（十五六 → 15-6，四十五六 → 45-6，七百三四十 → 730-40，一万六七 → 16000-7000） |
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

- WeText官方189条测试集（cardinal / date / time / money / measure
  / fraction / math / license_plate / whitelist / char / number /
  normalizer）：189/189 = 100%逐字节parity。
- Robustness测试集：手工挑选285条输入，覆盖19个true positive
  类别（cardinal small/hundreds/thousands/wan-yi/pure-digit、
  decimal、date、time、money、measure basic/range、fraction、math、
  license plate、phone、special_tilde、special_dash、mixed sentences）
  及6个false positive类别（78条输入：whitelist成语、纯文本、
  歧义的"一"+字符、"点"非小数语境、"年"非日期语境、嵌入成语的
  句子），目前100%通过。
- ParityTests：手写逐字节parity fixture（126条），100%通过。

合计：600条fixture + 74个显式test method，分布在5个test文件。

与两个参考库的对比：

| 测试资源              | ChineseITN-swift | WeTextProcessing | fun_text_processing (zh) |
| -------------------- | ---------------- | ---------------- | ------------------------ |
| 官方fixture条数       | 600              | 189（去重后）     | 0（zh无测试集，仅日语 / 印尼语提供） |
| False positive用例    | 78               | 0                | 0                        |
| 覆盖类别              | 19类TP + 6类FP   | 12类             | —                        |
| 单元test method数     | 74               | —                | —                        |

测试集是WeText的超集：先把它官方189条逐字纳入，再加411条新curate的
fixture（robustness集 + 手写parity fixture）。其中robustness集是两个
参考库都没有的——false positive保护（成语保留、纯中文、歧义"一"+
字符、"点"非小数、"年"非日期）覆盖了参考Python实现里完全没有的
回归场景。

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
