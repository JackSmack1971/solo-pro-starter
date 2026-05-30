# Frontend Integration Reference (wagmi v2 + Next.js App Router)

## Table of Contents
1. [Monorepo Frontend Layout](#layout)
2. [wagmi Config](#wagmi-config)
3. [App Router Provider Wrapper](#providers)
4. [Key Wagmi Hooks Cheatsheet](#hooks)
5. [ABI Wiring with viem Type Inference](#abi-wiring)
6. [Environment Variables](#env)

---

## Monorepo Frontend Layout {#layout}

```
apps/web/
├── src/
│   ├── app/
│   │   ├── layout.tsx          ← imports Providers wrapper
│   │   └── providers.tsx       ← WagmiProvider + QueryClientProvider
│   ├── abis/                   ← forge build output (as const exports)
│   │   └── MyContract.ts
│   ├── hooks/
│   │   ├── useEthersProvider.ts   ← Pattern A adapter (load only when needed)
│   │   └── useEthersSigner.ts     ← Pattern B adapter (load only when needed)
│   └── wagmi.config.ts         ← chain + connector configuration
├── .env.local                  ← secrets never committed
└── package.json
```

---

## wagmi Config {#wagmi-config}

> **Version note:** This reference targets wagmi v2. The current release is v3 — see the
> [wagmi v2 → v3 migration guide](https://wagmi.sh/react/guides/migrate-from-v2-to-v3)
> for connector/hook renames before upgrading.

```typescript
// src/wagmi.config.ts
import { http, createConfig, createStorage, cookieStorage } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'

const isDev = process.env.NODE_ENV === 'development'

/**
 * Factory function (not a static export) so the config is created fresh
 * on both server and client, which is required for proper SSR hydration.
 */
export function getConfig() {
  return createConfig({
    chains: isDev ? [foundry, sepolia] : [mainnet, sepolia],
    connectors: [
      injected(),
      walletConnect({ projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID! }),
    ],
    transports: {
      [mainnet.id]: http(),
      [sepolia.id]: http(),
    },
    ssr: true,
    // cookieStorage prevents "flash of disconnected state" on SSR hydration
    storage: createStorage({ storage: cookieStorage }),
  })
}
```

**Local dev override** — add `foundry` chain import alongside the factory:
```typescript
import { foundry } from 'wagmi/chains'  // chainId 31337 — built-in to wagmi

// Inside getConfig():
chains: isDev ? [foundry, sepolia] : [mainnet, sepolia],
transports: {
  [foundry.id]: http('http://127.0.0.1:8545'),
  [sepolia.id]: http(),
  [mainnet.id]: http(),
},
```

---

## App Router Provider Wrapper {#providers}

The layout must be an `async` Server Component to read the cookie header and pass initial
wagmi state down — this prevents the "flash of disconnected wallet" hydration mismatch.

```typescript
// src/app/providers.tsx  (Client Component)
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { type ReactNode, useState } from 'react'
import { WagmiProvider, type State } from 'wagmi'
import { getConfig } from '@/wagmi.config'

type ProvidersProps = { children: ReactNode; initialState?: State }

export function Providers({ children, initialState }: ProvidersProps) {
  // useState ensures config + queryClient are created once per client lifecycle
  const [config] = useState(() => getConfig())
  const [queryClient] = useState(() => new QueryClient())
  return (
    <WagmiProvider config={config} initialState={initialState}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

```typescript
// src/app/layout.tsx  (async Server Component — reads cookie for SSR hydration)
import type { ReactNode } from 'react'
import { headers } from 'next/headers'
import { cookieToInitialState } from 'wagmi'
import { getConfig } from '@/wagmi.config'
import { Providers } from './providers'

export default async function RootLayout({ children }: { children: ReactNode }) {
  // Reads the wagmi cookie set by the browser, rehydrates wallet state on the server
  const initialState = cookieToInitialState(
    getConfig(),
    (await headers()).get('cookie')
  )
  return (
    <html lang="en">
      <body>
        <Providers initialState={initialState}>
          {children}
        </Providers>
      </body>
    </html>
  )
}
```

---

## Key Wagmi Hooks Cheatsheet {#hooks}

```typescript
import {
  useAccount,                      // { address, chainId, isConnected, status }
  useBalance,                      // native token balance for an address
  useReadContract,                 // call view/pure functions — returns { data, error, isPending }
  useWriteContract,                // send mutating tx — returns { writeContract, data (hash), isPending }
  useWaitForTransactionReceipt,    // poll receipt after broadcast — returns { data, isLoading, isSuccess }
  useSimulateContract,             // dry-run before writing (gas estimation, revert checking)
  useClient,                       // low-level viem PublicClient
  useConnectorClient,              // low-level viem WalletClient (requires connected wallet)
  useSwitchChain,                  // prompt MetaMask/wallet to switch networks
  useDisconnect,                   // disconnect active wallet
  useEnsName,                      // resolve address → ENS name
  useEnsAddress,                   // resolve ENS name → address
} from 'wagmi'
```

**Read pattern:**
```typescript
const { data: balance, isPending } = useReadContract({
  address: '0xContractAddress' as `0x${string}`,
  abi: MY_CONTRACT_ABI,         // imported from abis/MyContract.ts
  functionName: 'balanceOf',
  args: [address],              // TypeScript checks args against ABI
})
```

**Write pattern (simulate → write → wait):**
```typescript
const { data: hash, isPending, writeContract } = useWriteContract()
const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

const handleTransfer = () => {
  writeContract({
    address: '0xContractAddress' as `0x${string}`,
    abi: MY_CONTRACT_ABI,
    functionName: 'transfer',
    args: ['0xRecipient' as `0x${string}`, 1_000_000_000_000_000_000n],  // BigInt only
  })
}
```

**Simulate before write (prevents on-chain reverts):**
```typescript
const { data: simulateData } = useSimulateContract({
  address: '0xContractAddress' as `0x${string}`,
  abi: MY_CONTRACT_ABI,
  functionName: 'transfer',
  args: ['0xRecipient' as `0x${string}`, 100n],
})

const { writeContract } = useWriteContract()
const handleWrite = () => {
  if (simulateData?.request) writeContract(simulateData.request)
}
```

---

## ABI Wiring with viem Type Inference {#abi-wiring}

The `as const` assertion on exported ABI arrays enables full compile-time type inference
for function signatures, argument types, and return types — zero manual typing needed.

```typescript
// apps/web/src/abis/MyToken.ts  — generated by scripts/export-abis.sh
export const MY_TOKEN_ABI = [
  {
    "type": "function",
    "name": "transfer",
    "inputs": [
      { "name": "to",     "type": "address" },
      { "name": "amount", "type": "uint256" }
    ],
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [{ "name": "account", "type": "address" }],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  }
] as const   // ← this single assertion unlocks full viem type inference
```

After importing `MY_TOKEN_ABI`, TypeScript will:
- Enforce correct argument count and types for each function
- Infer the return type of `balanceOf` as `bigint` automatically
- Reject mismatched `functionName` strings at compile time

---

## Environment Variables {#env}

```bash
# .env.local  — never commit this file
NEXT_PUBLIC_WC_PROJECT_ID=your_walletconnect_cloud_project_id
NEXT_PUBLIC_ALCHEMY_API_KEY=your_alchemy_key
NEXT_PUBLIC_DEFAULT_CHAIN_ID=1
```

Rules:
- `NEXT_PUBLIC_` prefix: safe to expose client-side (no secrets)
- Private keys, signing secrets, backend RPC URLs: server-only env vars without `NEXT_PUBLIC_`
- Never hardcode RPC URLs or API keys in source files
