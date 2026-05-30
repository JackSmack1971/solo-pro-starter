# README Production Checklist — 10 Points

Minimum passing score: **7 / 10**.
Run `python3 validate_readme.py <path>` for automated scoring.
Manual items below extend what the script cannot check.

## Automated Checks (validate_readme.py)

| # | Check | Pass Condition |
|---|---|---|
| 1 | H1 heading present | First non-blank line in top 5 starts with `# ` |
| 2 | ≥ 8 H2 sections | `grep -c "^## " README.md ≥ 8` |
| 3 | Code block present | ≥ 1 fenced code block (opening + closing ` ``` ` pair) |
| 4 | Badge or shield present | Contains `shields.io` URL or badge markdown pattern |
| 5 | No bare TODO | Zero `\bTODO\b` matches (case-insensitive) |
| 6 | Minimum line count | ≥ 60 lines |
| 7 | License mention | Word "license" appears in document |
| 8 | Installation / Quickstart | Contains "install", "quickstart", "quick start", or "getting started" |
| 9 | Contributing mention | Contains word beginning with "contribut" |
| 10 | No secret placeholders | No `YOUR_TOKEN`, `YOUR_API_KEY`, `YOUR_SECRET`, `INSERT_TOKEN`, `REPLACE_ME` |

## Manual Review Checklist

These items cannot be auto-scored and require human judgment:

- [ ] All `[INFERRED]` labels have been verified and replaced with accurate content.
- [ ] `REPO_OWNER/REPO_NAME` placeholders replaced with actual GitHub coordinates.
- [ ] Every code block runs without modification on a clean install.
- [ ] Mermaid diagram renders correctly (validate at https://mermaid.live).
- [ ] Mobile layout tested in GitHub preview (no horizontal scroll, short line lengths).

## Score Interpretation

| Score | Status | Action |
|---|---|---|
| 9–10 | Production-ready | Meets 2026 top-repo benchmarks; publish |
| 7–8 | Publishable | Minor cleanup; address manual checklist |
| < 7 | Remediation required | Re-run Phase 3 for missing sections |
