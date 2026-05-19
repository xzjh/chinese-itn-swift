"""Generate parity fixtures by running each input through the
reference Python library best suited for that category:

  - WeTextProcessing for: cardinal, decimal, time, money, fraction,
    measure, license_plate, math, whitelist (phone numbers via
    cardinal); broader coverage.
  - fun_text_processing for: date (年月日 separator format),
    electronic (URL / email recognition).

The Swift port must produce byte-identical output for every fixture.

Run via micromamba env that has both libraries installed:
    micromamba run -n wetext python scripts/generate_fixtures.py

Output: Tests/ChineseITNTests/Fixtures/parity.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


# (input, source_library) pairs grouped by category.
INPUTS_WETEXT = {
    # ---- Cardinal: pure cardinal expressions ----
    "cardinal_pure": [
        "一", "二", "九", "零", "两", "幺", "壹", "贰",
        "十", "十一", "十二", "十九",
        "二十", "二十一", "三十五", "九十九",
        "一百", "一百一", "一百二十三", "一百零一", "一百零五",
        "一千", "一千零一", "一千二百三十四", "一千零五十",
        "一万", "两万", "一万五千",
        "一千一", "一万一", "一万五", "一万零一",
    ],

    # ---- Cardinal in sentence (counter words handling) ----
    "cardinal_in_sentence": [
        "我有五十块钱",
        "团队从十五人扩到四十人",
        "估值涨了百分之三十",
        "这一轮我们融了大概二千五百万美金",
        "我大概要五十块钱",
        "再来一杯",
        "我说一句话",
    ],

    # ---- Decimal ----
    "decimal": [
        "三点二三",
        "二点五",
        "七点九九",
        "四点三三",
        "六十五点三",
        "二十一点五",
        "一百二十点五",
        "三百零五点零八",
        "变成四点三三G了",
        "原来你是四点零八个G",
        "三点二三。",
        "一百零一点零五",
    ],

    # ---- Time ----
    "time": [
        "下午三点",
        "下午三点四十五分",
        "下午三点半",
        "上午十点",
        "凌晨五点",
        "中午十二点",
        "晚上九点",
        "傍晚六点半",
        "三点半",
        "凌晨三点半会有雨",
    ],

    # ---- Money ----
    "money": [
        "五十块钱",
        "一百块钱",
        "三块五",
        "两千五百万美金",
        "我大概要五十块钱",
        "一千美金",
        "两百欧元",
    ],

    # ---- Fraction ----
    "fraction": [
        "三分之二",
        "百分之三十",
        "百分之二",
    ],

    # ---- License plate ----
    "license_plate": [
        "京A幺二三四五",
        "京A一二三四五",
        "沪B九八七六五",
    ],

    # ---- Whitelist (idiom protection) ----
    "whitelist": [
        "百闻不如一见",
        "做事不能三心二意",
        "千变万化",
        "我去过九寨沟",
        "三国演义",
        "星期一开会",
    ],

    # ---- Telephone (via WeText cardinal long-digit) ----
    "telephone": [
        "幺三八幺幺幺零零零零零",
        "我的手机号是幺三八幺幺幺二二二三三",
        "幺幺零",
        "加一二三四幺三八幺幺幺零零零零零",
    ],

    # ---- Mixed (multiple categories in one input) ----
    "mix": [
        "估值涨了百分之三十团队从十五人扩到四十人",
        "百闻不如一见一千零一夜也精彩",
        "内存占用四点零八G但是变成四点三三G了",
    ],
}

# fun_text_processing as truth oracle for these categories.
INPUTS_FUN = {
    "date": [
        "二零二六年五月四号",
        "二零二六年",
        "五月四号",
        "三月二十一日",
        "公元一六八年",
        "零八年奥运会",
    ],

    "electronic": [
        "h t t p 冒号斜杆斜杠 w w w 点 baidu 点 com",
    ],
}


def main():
    out_path = Path(__file__).resolve().parent.parent / "Tests" / "ChineseITNTests" / "Fixtures" / "parity.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    sys.path.insert(0, "/tmp/FunASR")
    from itn.chinese.inverse_normalizer import InverseNormalizer as WeText
    from fun_text_processing.inverse_text_normalization.inverse_normalize import InverseNormalizer as FunText
    we = WeText()
    fun = FunText(lang="zh")
    print("WeText + fun_text_processing loaded", file=sys.stderr)

    fixtures = []
    for category, inputs in INPUTS_WETEXT.items():
        for inp in inputs:
            try:
                expected = we.normalize(inp)
            except Exception as e:
                print(f"WeText ERROR on {category}/{inp!r}: {e}", file=sys.stderr)
                continue
            fixtures.append(dict(category=category, source="WeText", input=inp, expected=expected))

    for category, inputs in INPUTS_FUN.items():
        for inp in inputs:
            try:
                expected = fun.normalize(inp)
            except Exception as e:
                print(f"fun ERROR on {category}/{inp!r}: {e}", file=sys.stderr)
                continue
            fixtures.append(dict(category=category, source="fun_text_processing", input=inp, expected=expected))

    json.dump(fixtures, out_path.open("w"), ensure_ascii=False, indent=2)
    print(f"Wrote {len(fixtures)} fixtures to {out_path}", file=sys.stderr)

    # Print a quick summary
    by_cat: dict[str, list] = {}
    for f in fixtures:
        by_cat.setdefault(f["category"], []).append(f)
    for cat, items in sorted(by_cat.items()):
        src = items[0]["source"]
        print(f"  [{cat}] {len(items)} cases (from {src})")


if __name__ == "__main__":
    main()
