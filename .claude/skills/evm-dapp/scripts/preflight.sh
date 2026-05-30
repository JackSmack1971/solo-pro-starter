#!/usr/bin/env bash
# preflight.sh — EVM dApp pre-flight verification gate
#
# Usage:
#   bash preflight.sh [project-root]
#
# Checks:
#   1. forge test       — all smart contract tests pass
#   2. pnpm tsc         — zero TypeScript compilation errors
#   3. BigNumber grep   — no ethers.BigNumber usage in app source
#   4. v5 provider grep — no deprecated ethers v5 provider patterns
#   5. Untyped address  — no plain `address: string` declarations
#
# Exit codes:
#   0 — all checks passed (warnings allowed)
#   1 — one or more FAIL items; do not proceed

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "ERROR: project root '${PROJECT_ROOT}' is not a directory." >&2
  exit 1
fi

cd "$PROJECT_ROOT"

PASS=0
FAIL=0
WARN=0
ERRORS=()

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
pass() {
  echo "  ✓  $1"
  (( PASS++ )) || true
}

fail() {
  echo "  ✗  $1"
  (( FAIL++ )) || true
  ERRORS+=("FAIL: $1")
}

warn() {
  echo "  ⚠  $1"
  (( WARN++ )) || true
}

run_check() {
  local label="$1"; shift
  if "$@" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
}

grep_count() {
  # grep returns 1 when no match (not an error here); guard with || true
  # so pipefail does not abort the script on zero-match scans.
  { grep -r --include="*.ts" --include="*.tsx" \
      "$1" "${PROJECT_ROOT}/apps" "${PROJECT_ROOT}/packages" 2>/dev/null \
      || true; } \
    | wc -l | tr -d ' '
}

# ──────────────────────────────────────────────────────────────────────────────
# Header
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  EVM dApp Pre-Flight Gate"
echo "  Project: ${PROJECT_ROOT}"
echo "══════════════════════════════════════════════"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Check 1: forge test
# ──────────────────────────────────────────────────────────────────────────────
if command -v forge &>/dev/null; then
  if forge test --quiet > /dev/null 2>&1; then
    pass "forge test — all contract tests pass"
  else
    fail "forge test — one or more tests failing (run 'forge test -vvv' for details)"
  fi
else
  warn "forge not found — skipping contract tests (install via: curl -L https://foundry.paradigm.xyz | bash)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 2: pnpm tsc --noEmit
# ──────────────────────────────────────────────────────────────────────────────
if command -v pnpm &>/dev/null; then
  if pnpm tsc --noEmit > /dev/null 2>&1; then
    pass "pnpm tsc --noEmit — zero TypeScript errors"
  else
    fail "pnpm tsc --noEmit — TypeScript errors found (run 'pnpm tsc --noEmit' to see details)"
  fi
else
  warn "pnpm not found — skipping TypeScript check (install via: npm i -g pnpm)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 3: No ethers.BigNumber usage
# ──────────────────────────────────────────────────────────────────────────────
if [[ -d "${PROJECT_ROOT}/apps" ]] || [[ -d "${PROJECT_ROOT}/packages" ]]; then
  BN_COUNT=$(grep_count "ethers\.BigNumber\|BigNumber\.from\b")
  if [[ "$BN_COUNT" -eq 0 ]]; then
    pass "No ethers.BigNumber references — native BigInt used throughout"
  else
    fail "ethers.BigNumber found in ${BN_COUNT} line(s) — replace with native BigInt (e.g., 1_000n)"
  fi
else
  warn "apps/ and packages/ directories not found — skipping BigNumber check"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 4: No legacy ethers v5 providers
# ──────────────────────────────────────────────────────────────────────────────
if [[ -d "${PROJECT_ROOT}/apps" ]] || [[ -d "${PROJECT_ROOT}/packages" ]]; then
  V5_COUNT=$(grep_count "providers\.Web3Provider\|ethers\.providers\.")
  if [[ "$V5_COUNT" -eq 0 ]]; then
    pass "No legacy ethers v5 provider patterns"
  else
    fail "ethers v5 provider pattern found in ${V5_COUNT} line(s) — use viem clients or Pattern A/B adapters"
  fi
else
  warn "Skipping legacy provider check (source directories not found)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 5: No untyped address fields
# ──────────────────────────────────────────────────────────────────────────────
if [[ -d "${PROJECT_ROOT}/apps" ]] || [[ -d "${PROJECT_ROOT}/packages" ]]; then
  ADDR_COUNT=$(grep_count "address:\s*string\b")
  if [[ "$ADDR_COUNT" -eq 0 ]]; then
    pass "No untyped 'address: string' fields — viem Address type used"
  else
    warn "Untyped 'address: string' found in ${ADDR_COUNT} line(s) — consider replacing with viem Address type"
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
printf "  PASS: %-3s  WARN: %-3s  FAIL: %s\n" "$PASS" "$WARN" "$FAIL"
echo "──────────────────────────────────────────────"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "  PRE-FLIGHT FAILED — resolve the following before proceeding:"
  for err in "${ERRORS[@]}"; do
    echo "    → $err"
  done
  echo ""
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo ""
  echo "  PRE-FLIGHT PASSED WITH WARNINGS"
  echo "  Review warnings before deploying to mainnet."
  echo ""
  exit 0
else
  echo ""
  echo "  PRE-FLIGHT PASSED — all checks green."
  echo ""
  exit 0
fi
