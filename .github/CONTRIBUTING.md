# Contributing to solo-pro-starter

Thank you for improving this scaffold. Contributions are issue-driven — every change starts with an issue and lands through a pull request.

## Ground Rules

- One issue per branch. One branch per PR.
- No direct commits to `main`.
- Read the repository before editing it.
- Update tests or docs when behavior changes.
- Run `/fsv-verify` after every write or external mutation.

## Getting Started

1. **Fork** the repository and clone your fork.
2. **Open an issue** describing the problem or improvement before writing code.
3. **Create a branch** from `main` named after the issue: `feat/123-add-xyz` or `fix/456-broken-hook`.
4. **Make your change** — keep diffs small and reviewable.
5. **Open a PR** using the pull request template.

## High-Risk Areas

Changes to these paths are treated as **privileged** and require extra scrutiny:

| Path | Risk |
|---|---|
| `.claude/settings.json` | Permissions, hooks, and model settings affect every session |
| `.claude/rules/` | Path-scoped rules load automatically; incorrect rules silently misbehave |
| `.claude/skills/*/scripts/` | Shell scripts executed by Claude Code — injection risk |
| `.claude/agents/` | Subagent role definitions affect autonomous behavior |
| `.github/workflows/` | CI changes have repository-wide blast radius |

PRs touching these paths **must** include:
- A verification section showing the change was tested
- A risk note explaining what could go wrong
- A rollback path

## Adding a New Skill

1. Create `.claude/skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`, `argument-hint`, `allowed-tools`).
2. Add reference files under `.claude/skills/<skill-name>/references/` as needed.
3. Add scripts under `.claude/skills/<skill-name>/scripts/` if the skill needs shell execution.
4. Register the skill in:
   - The **Developer Command Center** skills table in `README.md`
   - The **Scaffold Directory Structure** tree in `README.md`
   - The **Features** bullet count in `README.md`
   - The `expected_skills` list in `.github/workflows/ci.yml`

## Adding a New Rule

1. Create `.claude/rules/<rule-name>.md`.
2. Add a `paths:` frontmatter block if the rule should be path-scoped.
3. Update `.claude/rules/README.md` to document the new rule's purpose and composition order.
4. Update the **Features** bullet in `README.md` if the rule count changes.

## Commit Style

Use the imperative mood in the subject line. Keep the subject under 72 characters.

```
Add evm-dapp skill with viem-first policy and preflight gate
Fix ci.yml: pin checkout action to SHA and add least-privilege permissions
Update README: add troubleshooting entry for missing hook scripts
```

Always append the co-author trailer when assisted by Claude Code:

```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Be respectful and constructive.

## Questions

Open a [GitHub Discussion](https://github.com/JackSmack1971/solo-pro-starter/discussions) rather than an issue for general questions.
