"""Generate parity fixtures from WeTextProcessing's official test
suite at /tmp/WeText/itn/chinese/test/data/*.txt.

Format: each line is "<spoken> => <written>". Some files are
configuration-specific (enable_standalone_number / enable_0_to_9
flags), which we skip — we use the default-flag suite that matches
our Swift port's intended behavior.

This is the THOROUGH parity test corpus: 285 official WeText cases.

Run via:
    micromamba run -n wetext python scripts/generate_fixtures_official.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

OFFICIAL_DIR = Path("/tmp/WeText/itn/chinese/test/data")
OUT_PATH = Path(__file__).resolve().parent.parent / "Tests" / "ChineseITNTests" / "Fixtures" / "parity_official.json"

# Categories to import. Skip flag-specific normalizer_*.txt and
# license_plate (Cardinal scanner handles via length match).
CATEGORIES = [
    "cardinal", "char", "date", "fraction", "math",
    "measure", "money", "time", "whitelist", "number",
    "license_plate", "normalizer",
]


def parse_test_case(path: Path):
    """Parse WeText's test case format: <spoken> => <written>."""
    cases = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if " => " not in line:
            continue
        spoken, written = line.split(" => ", 1)
        cases.append((spoken.strip(), written.strip()))
    return cases


def main():
    if not OFFICIAL_DIR.exists():
        print(f"WeText test data not found at {OFFICIAL_DIR}. Clone the upstream repo first.", file=sys.stderr)
        return 1

    fixtures = []
    for cat in CATEGORIES:
        path = OFFICIAL_DIR / f"{cat}.txt"
        if not path.exists():
            continue
        for spoken, written in parse_test_case(path):
            fixtures.append(dict(
                category=cat,
                source="WeText official",
                input=spoken,
                expected=written,
            ))

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(fixtures, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(fixtures)} official-WeText fixtures to {OUT_PATH}", file=sys.stderr)

    by_cat: dict[str, int] = {}
    for f in fixtures:
        by_cat[f["category"]] = by_cat.get(f["category"], 0) + 1
    for cat in sorted(by_cat):
        print(f"  [{cat}] {by_cat[cat]} cases", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main() or 0)
