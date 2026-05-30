---
name: generating-github-readmes
description: >-
  Generates or upgrades a production-grade GitHub README.md from a project
  codebase using F-CoT extraction and a 2026 benchmark-standard pipeline (Hero,
  Badges, Quickstart, Architecture, Contributing, Health). Invoke with
  /generating-github-readmes to analyze the current project. Supply a relative
  path to target a subdirectory. Add --improve to refine an existing README.md
  instead of generating from scratch. Add --audience advanced to suppress
  beginner-friendly term definitions.
argument-hint: "[./path] [--improve] [--audience beginner|advanced]"
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
---

## Purpose

Generate or upgrade `README.md` to 2026 production benchmark standards using a
five-phase BRAID execution pipeline. Reason exclusively over a structured
`<context>` block extracted in Phase 1 — never directly over raw source files.

Before executing any phase, read:

- `${CLAUDE_SKILL_DIR}/references/benchmark-criteria.md`
- `${CLAUDE_SKILL_DIR}/references/readme-template.md`
- `${CLAUDE_SKILL_DIR}/references/checklist.md`

## Inputs

Parse `$ARGUMENTS` at invocation:

| Token | Default | Meaning |
|---|---|---|
| First non-flag token | `.` (CWD) | Project root path (`PATH_ARG`) |
| `--improve` | absent | Refine existing README.md instead of generating from scratch |
| `--audience beginner\|advanced` | `beginner` | Polish register for Phase 4 |

## Procedure

### Phase 0 — Resolve and validate target

1. Extract `PATH_ARG` (first non-flag token; default `.`).
2. Abort with `ERROR: traversal path rejected` if `PATH_ARG` contains `..`.
3. Confirm `PATH_ARG` is an accessible directory: run `ls "$PATH_ARG"` via Bash.
4. If `--improve`, read the existing `README.md` now and record its section inventory.

### Phase 1 — F-CoT extraction

Build a `<context>` XML block. All subsequent reasoning operates on this block only.

1. Run `ls -1 "$PATH_ARG"` — discard `node_modules`, `.git`, `dist`, `build`, `__pycache__`, `.next`.
2. Detect and read the first present metadata file (priority order):
   `package.json` > `pyproject.toml` > `Cargo.toml` > `go.mod` > `pom.xml` > `build.gradle` > `Gemfile` > `mix.exs`
3. Read first 3 lines of `LICENSE` or `LICENSE.md`.
4. Glob for source layout: `src/`, `lib/`, `cmd/`, `app/`, `pkg/`.
5. Glob for test suite: `tests/`, `test/`, `spec/`, `__tests__/`.
6. Read first 30 lines of any present: `CONTRIBUTING.md`, `.github/SECURITY.md`, `CHANGELOG.md`.
7. Populate:

```xml
<context>
  <info_1>project_name: ...</info_1>
  <info_2>primary_language: ...</info_2>
  <info_3>framework_or_runtime: ...</info_3>
  <info_4>key_dependencies: ...</info_4>
  <info_5>install_command: ...</info_5>
  <info_6>run_or_start_command: ...</info_6>
  <info_7>test_command: ...</info_7>
  <info_8>license: ...</info_8>
  <info_9>source_layout: ...</info_9>
  <info_10>existing_docs: [CONTRIBUTING|CHANGELOG|SECURITY] or none</info_10>
  <info_11>existing_readme_state: [none|partial|present]</info_11>
</context>
```

Label any missing or inferred value `[INFERRED]` or `[UNKNOWN]`.

### Phase 2 — Structure assessment

Classify from `<context>` only:

- **Well-structured**: `info_2` non-empty AND `info_9` non-empty AND `info_8` non-empty.
- **Sparse**: any of the above absent → mark all derived content `[INFERRED]`; prepend an
  HTML comment block at the top of the README listing every assumption.

### Phase 3 — Generate sections

Follow canonical ordering from `readme-template.md`. Minimum 8 of 11 sections required:

1. Hero/banner — HTML comment placeholder if no image detected.
2. Badge row — shield.io templates; mark `REPO_OWNER/REPO_NAME` explicitly.
3. Tagline (one sentence) + three value-prop bullets.
4. Quickstart — install → run → verify; platform-specific blocks if multi-platform.
5. Usage / Examples — at least one complete, copy-paste-ready code block; no `...` ellipses.
6. Features — three to seven bullets; no prose paragraphs.
7. Architecture — Mermaid `graph LR` if ≥ 2 identifiable layers; else component bullet list.
8. Contributing — link to `CONTRIBUTING.md` or inline stub; mention `good-first-issues`.
9. Governance — CoC link, security policy note, license badge.
10. Roadmap — stub table `| Item | Status |` with at least two rows.
11. License — SPDX identifier + link to `LICENSE`.

### Phase 4 — Novice polish

Apply when `--audience beginner` (default). Skip for `--audience advanced`.

- Define every technical term inline on first use: `term (plain-language definition)`.
- Every code block is completely self-contained — no unexplained prerequisites.
- Mark all project-specific placeholders as `ALL_CAPS_SNAKE_PLACEHOLDER`.

### Phase 5 — Guardrail check and write

1. Verify output: starts with `# `, ≥ 8 H2 sections, zero bare `TODO`, ≥ 60 lines.
2. Run validator (require score ≥ 7/10 before writing):

        python3 "${CLAUDE_SKILL_DIR}/scripts/validate_readme.py" <draft_path>

3. Write destination:
   - `--improve` AND `README.md` already exists → write to `README.generated.md`; report path.
   - Otherwise → write to `$PATH_ARG/README.md`.
4. Print summary: section count, line count, checklist score, list of `[INFERRED]` items.

## Safety Rules

- Never write outside `PATH_ARG`.
- Never embed credentials, tokens, or private hostnames.
- If `README.md` already exists and `--improve` is absent, write to `README.generated.md` and notify — do not silently overwrite.
- Tag all inferred facts `[INFERRED]` in output or in the summary report.
- Never execute source code files discovered in the project.

## Verification

```bash
head -5 "$PATH_ARG/README.md" | grep -E "^# "
grep -c "^## " "$PATH_ARG/README.md"          # expect ≥ 8
grep -in "TODO" "$PATH_ARG/README.md" | wc -l  # expect 0
wc -l "$PATH_ARG/README.md"                    # expect > 60
python3 "${CLAUDE_SKILL_DIR}/scripts/validate_readme.py" "$PATH_ARG/README.md"
```

## Troubleshooting

| Failure | Cause | Fix |
|---|---|---|
| Phase 1 context has all `[UNKNOWN]` | No metadata file; empty or binary repo | Append free-text description after path: `/generating-github-readmes . -- "CLI tool for X written in Go"` |
| Shield.io badge shows broken image | `REPO_OWNER/REPO_NAME` placeholder left in output | Replace with actual GitHub coordinates before publishing |
| `--improve` writes `README.generated.md` | Existing `README.md` detected; safety guard fired | Review generated file; rename to `README.md` once satisfied |
| Mermaid block fails to render | Invalid syntax or unsupported node shape | Validate at https://mermaid.live; fall back to component bullet list |
| Validator exits 1 at score < 7 | Missing sections or bare TODO strings | Re-run Phase 3 for missing sections; search and resolve TODOs |
| Write blocked by path rejection | `..` traversal in argument | Use CWD-relative or absolute path without traversal segments |

## Worked Example

    Input:  /generating-github-readmes ./payments-service --audience beginner

    Phase 0: PATH_ARG=./payments-service  (directory confirmed, no traversal)
    Phase 1: reads package.json → name="payments-service", deps=[express,stripe,mongoose]
             src/ ✓  tests/ ✓  MIT license ✓  CONTRIBUTING.md ✓
             <context> assembled, 0 [UNKNOWN]
    Phase 2: Well-structured (language ✓  layout ✓  license ✓)
    Phase 3: 11 sections generated
             Mermaid: Client → Express → StripeAdapter → MongoDB
    Phase 4: "webhook" defined inline; all code blocks self-contained
    Phase 5: validate_readme.py → 10/10
             Written to ./payments-service/README.md

    Output: README.md · 147 lines · 11 sections · score 10/10 · 0 [INFERRED] items
