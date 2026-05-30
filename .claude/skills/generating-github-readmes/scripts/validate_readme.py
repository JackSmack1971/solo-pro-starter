#!/usr/bin/env python3
"""
validate_readme.py — Production README quality gate.
Usage : python3 validate_readme.py <path/to/README.md>
Exits : 0 if score >= 7/10 | 1 if score < 7 | 2 on file/arg error
"""

import argparse
import re
import sys
from pathlib import Path


def load_lines(path: Path) -> list:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"ERROR: Cannot read {path}: {exc}", file=sys.stderr)
        sys.exit(2)
    return text.splitlines(), text, text.lower()


def chk(label: str, passed: bool, detail: str = "") -> bool:
    status = "PASS" if passed else "FAIL"
    line = f"  [{status}] {label}"
    if detail:
        line += f"  ({detail})"
    print(line)
    return passed


def main() -> None:
    parser = argparse.ArgumentParser(description="README production quality gate.")
    parser.add_argument("readme", help="Path to README.md to validate.")
    args = parser.parse_args()

    path = Path(args.readme).resolve()
    if not path.exists():
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(2)
    if not path.is_file():
        print(f"ERROR: Not a file: {path}", file=sys.stderr)
        sys.exit(2)

    # Belt-and-suspenders: warn if outside CWD, but still validate read-only
    try:
        path.relative_to(Path.cwd())
    except ValueError:
        print(f"WARNING: {path} is outside CWD — validating read-only.", file=sys.stderr)

    lines, text, text_lo = load_lines(path)
    results = []

    # 1 — H1 heading in first 5 lines
    results.append(chk(
        "H1 heading present (first 5 lines)",
        any(ln.startswith("# ") for ln in lines[:5]),
    ))

    # 2 — Minimum H2 section count
    h2 = sum(1 for ln in lines if re.match(r"^## ", ln))
    results.append(chk("≥ 8 H2 sections", h2 >= 8, f"found {h2}"))

    # 3 — At least one fenced code block (pair of fence markers)
    fences = sum(1 for ln in lines if ln.strip().startswith("```"))
    results.append(chk("≥ 1 fenced code block", fences >= 2, f"fence markers: {fences}"))

    # 4 — Badge / shield present
    has_badge = bool(re.search(r"shields\.io|badge/|!\[.*?\]\(https?://", text))
    results.append(chk("Badge or shield present", has_badge))

    # 5 — No bare TODO
    todo_lines = [i + 1 for i, ln in enumerate(lines)
                  if re.search(r"\bTODO\b", ln, re.IGNORECASE)]
    results.append(chk(
        "No bare TODO strings",
        len(todo_lines) == 0,
        f"lines: {todo_lines[:5]}" if todo_lines else "",
    ))

    # 6 — Minimum line count
    results.append(chk("≥ 60 lines", len(lines) >= 60, f"actual: {len(lines)}"))

    # 7 — License section or mention
    results.append(chk("License mentioned", bool(re.search(r"\blicense\b", text_lo))))

    # 8 — Installation / quickstart section
    results.append(chk(
        "Installation or Quickstart section",
        bool(re.search(r"\b(install|quickstart|quick start|getting started)\b", text_lo)),
    ))

    # 9 — Contributing mention
    results.append(chk(
        "Contributing section or mention",
        bool(re.search(r"\bcontribut", text_lo)),
    ))

    # 10 — No exposed secret placeholders
    secret = re.search(
        r"\b(YOUR_TOKEN|YOUR_API_KEY|YOUR_SECRET|INSERT_TOKEN|REPLACE_ME)\b",
        text, re.IGNORECASE,
    )
    results.append(chk(
        "No exposed secret placeholders",
        secret is None,
        f"found: {secret.group()}" if secret else "",
    ))

    score = sum(results)
    total = len(results)
    threshold = 7

    print()
    print(f"Score   : {score}/{total}")
    print(f"Result  : {'PASS' if score >= threshold else 'FAIL'}"
          f"  (threshold {threshold}/{total})")

    sys.exit(0 if score >= threshold else 1)


if __name__ == "__main__":
    main()
