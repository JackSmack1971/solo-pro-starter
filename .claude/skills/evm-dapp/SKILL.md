---
name: evm-dapp
description: "Enforces the viem-first EVM full-stack development policy for Ethereum/EVM projects. Activate when writing Solidity contracts, configuring viem/wagmi frontends, generating ethers.js v6 adapter layers, scaffolding full-stack dApp monorepos, or resolving viem-ethers interop errors. Trigger keywords: viem, wagmi, ethers, dApp, EVM, Solidity, smart contract, ABI, wallet adapter, blockchain frontend, Foundry, forge, cast, anvil, useAccount, useWriteContract, useConnectorClient."
argument-hint: "[scaffold|adapter <sdk-name>|audit|devnode]"
allowed-tools:
  - Bash
  - Read
  - Write
---

# EVM Full-Stack TypeScript Development Protocol

**Required stack:** `node>=20 · pnpm>=9 · viem^2 · wagmi^2 · ethers^6 · foundry>=1.0.0 · next>=14 · tailwindcss>=3`

---

## 1. Tooling Mandate

Restrict all code generation to this exact stack. Do not propose alternatives.

| Layer | Required Tool | Hard Constraint |
|---|---|---|
| Workspace | pnpm workspaces | No npm/yarn |
| Contracts | Foundry (`forge` / `cast` / `anvil`) | No Hardhat, Truffle, or Brownie |
| Frontend | Next.js App Router + React + Tailwind | Pages Router is legacy; reject it |
| Web3 state | wagmi v2 + TanStack Query | No web3-react, no custom Provider context |
| Chain client | viem v2 | No web3.js |
| Legacy interop | ethers.js v6 — adapter layer **only** | Never store ethers objects in app state |

---

## 2. Operational Routing Matrix

Load the matching reference file **before generating any code** for these task types.
Use the Bash tool to cat the file, then proceed.

```
Solidity contracts or forge operations     →  cat "${CLAUDE_SKILL_DIR}/references/solidity-contracts.md"
wagmi config, hooks, or React state        →  cat "${CLAUDE_SKILL_DIR}/references/frontend-integration.md"
Any ethers.js adapter or third-party SDK   →  cat "${CLAUDE_SKILL_DIR}/references/ethers-viem-adapters.md"
Local devnode, Anvil, or Docker chain      →  cat "${CLAUDE_SKILL_DIR}/references/local-devnode.md"
```

Rationale: loading only the relevant reference prevents token waste and context pollution
(e.g., Rust/Stylus compilation details must not enter context during a CSS change).

---

## 3. Compilation & ABI Export Pipeline

After any Solidity contract is created or modified:

1. Run `forge build`
2. Run `bash "${CLAUDE_SKILL_DIR}/scripts/export-abis.sh"` from the monorepo root
3. Verify `apps/web/src/abis/<ContractName>.ts` was written with `as const`
4. Wire into wagmi via `useReadContract` / `useWriteContract` — **never** `new ethers.Contract()`

If `export-abis.sh` is unavailable, write the ABI file manually:
```ts
// apps/web/src/abis/MyContract.ts  — auto-generated, do not edit
export const MY_CONTRACT_ABI = [ /* ABI array */ ] as const
```

---

## 4. Library Interoperability Guardrails

| Rule | Correct | Forbidden |
|---|---|---|
| Frontend wallet state | `useAccount`, `useClient`, `useConnectorClient` | `useState(signer)`, persistent ethers objects |
| Numeric values | `1_000_000_000_000_000_000n` (native BigInt) | `ethers.BigNumber.from(...)` or ethers `parseEther` |
| Adapter scope | Instantiated inline per component; not stored | React Context, Zustand, Redux holding ethers types |
| Address types | `Address` (viem) or `` `0x${string}` `` | Plain `string` for addresses |

**Adapter rule:** Before writing any adapter for a third-party SDK that requires an ethers.js
`Provider` or `Signer`, load `references/ethers-viem-adapters.md` (Routing Matrix, row 3).

---

## 5. Pre-Flight Verification Gate

Run before presenting any contract change or wallet-connection modification:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh"
```

Gate checks:
- `forge test` — all unit and fuzz tests pass
- `pnpm tsc --noEmit` — zero TypeScript errors
- No `ethers.BigNumber` or `.BigNumber.from` in `apps/` or `packages/`
- No legacy `providers.Web3Provider` or `ethers.providers.` in source
- No untyped `address: string` fields (must use viem `Address`)

**Fix every FAIL before presenting code.** Never resolve TypeScript errors with `any` overrides.

---

## 6. Slash Command Dispatch (`$ARGUMENTS`)

| Argument | Action |
|---|---|
| `scaffold` | Generate pnpm monorepo skeleton: `apps/web` (Next.js) + `packages/contracts` (Foundry) |
| `adapter <sdk-name>` | Load `references/ethers-viem-adapters.md`; generate typed adapter file for the named SDK |
| `audit` | Run pre-flight gate only; print full results table |
| `devnode` | Load `references/local-devnode.md`; configure and start Anvil with correct wagmi chain config |
| *(empty)* | Apply full policy to the current task context |

---

## 7. Worked Example

**Input:** `/evm-dapp adapter safe-core-sdk` — "Wire up Safe Core SDK for a multi-sig transaction"

**Steps:**
1. Load `references/ethers-viem-adapters.md` (Routing Matrix — adapter task, Pattern B)
2. Import `useEthersSigner` hook from `src/hooks/useEthersSigner.ts`
3. Scope `signer` to the component; pass to `SafeApiKit` and `Safe` SDK inline
4. Do **not** store `signer` in `useState`, context, or any global store

**Output:** React component calling `useEthersSigner()` per-render, creating the Safe SDK
instance locally, executing the multi-sig transaction, zero persistent ethers state.
