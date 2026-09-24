#!/usr/bin/env python3
"""grade-review.py <review.md> <findings.tsv> [threshold]

Checks which planted defects a review mentions (case-insensitive regex per row) and
prints PASS/FAIL per finding plus `FOUND n/N`. Exit 0 iff n >= threshold (default 9).
"""

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    review = Path(sys.argv[1]).read_text()
    threshold = int(sys.argv[3]) if len(sys.argv) > 3 else 9
    found = total = 0
    for raw in Path(sys.argv[2]).read_text().splitlines():
        if not raw or raw.startswith("#") or raw.startswith("id\t"):
            continue
        fid, regex, label = (raw.split("\t") + [""] * 3)[:3]
        total += 1
        if re.search(regex, review, re.I | re.S):
            found += 1
            print(f"PASS {fid}  {label}")
        else:
            print(f"FAIL {fid}  {label}")
    print(f"FOUND {found}/{total} (threshold {threshold})")
    return 0 if found >= threshold else 1


if __name__ == "__main__":
    sys.exit(main())
