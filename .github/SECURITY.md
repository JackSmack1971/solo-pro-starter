# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 1.x (latest) | ✅ |
| < 1.0 | ❌ |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report security issues privately using one of the following channels:

1. **GitHub Private Vulnerability Reporting** (preferred) — use the [Security tab](../../security/advisories/new) on this repository to submit a private advisory.
2. **Email** — send details to the maintainer at the address listed on the [GitHub profile](https://github.com/JackSmack1971).

### What to include

- A clear description of the vulnerability and its potential impact
- Steps to reproduce or a minimal proof-of-concept
- Affected versions or file paths within `.claude/`
- Any suggested mitigations

### What to expect

- **Acknowledgement** within 48 hours
- **Assessment** within 7 days — confirmed, disputed, or declined with reasoning
- **Fix or advisory** within 30 days for confirmed findings

## Scope

This repository is a Claude Code configuration scaffold — it contains no compiled binaries, no backend services, and no on-chain contracts. The primary security surfaces are:

| Surface | Risk |
|---|---|
| `.claude/settings.json` permission deny rules | Misconfiguration could expose `.env` files or allow destructive shell commands |
| `.github/workflows/ci.yml` | Supply-chain risk via unpinned action dependencies |
| `.claude/skills/*/scripts/` | Shell scripts executed by Claude Code hooks |
| `CLAUDE.md` / `AGENTS.md` | Prompt-injection risk if untrusted content is inserted |

## Out of Scope

- Vulnerabilities in Claude Code itself (report to [Anthropic](https://www.anthropic.com/security))
- Vulnerabilities in viem, ethers, Foundry, or wagmi (report to their respective maintainers)
- Issues in repositories that *use* this scaffold but are not part of this repository
