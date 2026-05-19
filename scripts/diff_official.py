"""Inspect official-corpus parity failures per category. Helps decide
which patterns to add next.

Run via: python3 scripts/diff_official.py [category]
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

# We can't directly invoke Swift from here. Instead, dump fixtures
# and a Swift binary CLI would produce outputs. For now, show
# expected vs current behavior groupings.
#
# This is a placeholder; real diff comes from `swift test` output.

PATH = Path("Tests/ChineseITNTests/Fixtures/parity_official.json")
fxs = json.loads(PATH.read_text(encoding="utf-8"))

cat_filter = sys.argv[1] if len(sys.argv) > 1 else None
for f in fxs:
    if cat_filter and f["category"] != cat_filter:
        continue
    print(f"[{f['category']}] {f['input']!r:80s} -> {f['expected']!r}")
