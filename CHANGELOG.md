# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-30

### Added

- Root `CLAUDE.md` with operating model, source-of-truth command discovery, stack defaults, engineering rules, protected areas, and PR expectations
- Root `AGENTS.md` with issue-driven agent rules and merge policy
- `.claude/settings.json` — shared guardrails: model, permissions allow/deny lists, confirmation gates, branch protection, lifecycle hooks, and env defaults
- `.claude/rules/` — 12 path-scoped operating constraint files: `architecture`, `security`, `testing`, `frontend-wallets`, `smart-contracts`, `chain-config`, `generated-artifacts`, `github-release-workflows`, `transaction-execution`, `onchain-data-consistency`, `upgrade-admin-surfaces`, `signatures-and-permits`
- `.claude/skills/` — 7 reusable skills: `stack-detection`, `auditing-wallet-flows`, `auditing-contract-surfaces`, `verifying-deployment-safety`, `dependency-audit`, `repo-audit`, `fsv-verify`; plus `generating-github-readmes` skill with BRAID pipeline, benchmark criteria, readme template, checklist, and validator script
- `.claude/agents/` — 5 isolated subagent role definitions: `implementation-agent`, `pr-reviewer`, `release-gatekeeper`, `upstream-auditor`, `web3-auditor`
- `.claude/commands/` — namespaced slash commands: `create:pr`, `review:pr`, `audit:upstream`, `audit:web3`, `release:readiness` with legacy top-level aliases
- `assets/banner.jpg` — project hero image
- Production `README.md` — 331-line developer command center with quickstart, command matrix, collapsible skill/agent/hook reference, scaffold directory tree, troubleshooting matrix, 9-row stack inventory, reproducibility and maintenance section, Mermaid architecture diagram, and full governance/roadmap/license sections

### Notes

- No runtime code — this is a pure scaffold. Verification is structural (expected `.claude/` paths exist, referenced files exist).
- Lifecycle hook scripts (`session-start.js`, `pre-tool-use.js`, `post-tool-use.js`, `stop.js`) and workflow orchestration scripts (`issue-to-pr.js`, `web3-audit.js`, `release-readiness.js`) are planned for a future release.
- License assumed MIT pending addition of a `LICENSE` file.

[1.0.0]: https://github.com/JackSmack1971/solo-pro-starter/releases/tag/v1.0.0
