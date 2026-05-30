# Ethers.js v6 ↔ Viem Adapter Reference

## Table of Contents
1. [Pattern A: viem Client → ethers.js v6 Provider (read-only)](#pattern-a)
2. [Pattern B: viem Connector Client → ethers.js v6 Signer (write)](#pattern-b)
3. [Pattern C: ethers.js Provider → viem WalletClient (reverse bridge, Node.js only)](#pattern-c)
4. [Usage Matrix & Anti-Patterns](#usage-matrix)

---

## Pattern A — viem Client → ethers.js v6 Provider {#pattern-a}

**When to use:** A third-party SDK requires a read-only `Provider`
(e.g., Safe Protocol Kit, CoW Protocol SDK, Aave SDK, Lens Protocol).

**File location:** `packages/adapters/src/clientToProvider.ts`

```typescript
import { FallbackProvider, JsonRpcProvider } from 'ethers'
import { useMemo } from 'react'
import type { Chain, Client, Transport } from 'viem'
import { fallback } from 'viem'
import { type Config, useClient } from 'wagmi'

/**
 * Converts a viem Client (Transport + Chain) to an ethers.js v6 Provider.
 * Handles fallback transports by mapping them to a FallbackProvider.
 */
export function clientToProvider(
  client: Client<Transport, Chain>
): JsonRpcProvider | FallbackProvider {
  const { chain, transport } = client
  const network = {
    chainId: chain.id,
    name: chain.name,
    ensAddress: chain.contracts?.ensRegistry?.address,
  }

  if (transport.type === 'fallback') {
    const providers = (
      transport.transports as ReturnType<typeof fallback>['transports']
    ).map(
      ({ value }) =>
        new JsonRpcProvider(value?.url, network, { staticNetwork: true })
      // { staticNetwork: true } skips redundant eth_chainId calls — performance win
    )
    if (providers.length === 1) return providers[0]
    return new FallbackProvider(providers)
  }

  return new JsonRpcProvider(transport.url, network, { staticNetwork: true })
}

/**
 * React hook: converts the active wagmi chain client to an ethers.js v6 Provider.
 * Pass chainId to pin to a specific network.
 */
export function useEthersProvider({ chainId }: { chainId?: number } = {}) {
  const client = useClient<Config>({ chainId })
  return useMemo(
    () => (client ? clientToProvider(client) : undefined),
    [client]
  )
}
```

**Usage:**
```typescript
import { useEthersProvider } from '@/hooks/useEthersProvider'

function QuoteWidget() {
  const provider = useEthersProvider()
  const getQuote = async () => {
    if (!provider) return
    const cowSdk = new CowSdk({ chainId: 1, provider })  // SDK gets Provider
    return cowSdk.getQuote(...)
  }
}
```

---

## Pattern B — viem Connector Client → ethers.js v6 Signer {#pattern-b}

**When to use:** A third-party SDK requires a signing `Signer` to execute state-changing
transactions (e.g., Safe Core SDK, Unlock Protocol, AppKit, Gnosis Pay).

**File location:** `packages/adapters/src/clientToSigner.ts`

```typescript
import { BrowserProvider, JsonRpcSigner } from 'ethers'
import { useMemo } from 'react'
import type { Account, Chain, Client, Transport } from 'viem'
import { type Config, useConnectorClient } from 'wagmi'

/**
 * Converts a viem Connector Client (with connected account) to an ethers.js v6 JsonRpcSigner.
 */
export function clientToSigner(
  client: Client<Transport, Chain, Account>
): JsonRpcSigner {
  const { account, chain, transport } = client
  const network = {
    chainId: chain.id,
    name: chain.name,
    ensAddress: chain.contracts?.ensRegistry?.address,
  }
  const provider = new BrowserProvider(transport, network)
  return new JsonRpcSigner(provider, account.address)
}

/**
 * React hook: returns an ethers.js v6 Signer for the currently connected wallet.
 * Returns undefined when no wallet is connected.
 */
export function useEthersSigner({ chainId }: { chainId?: number } = {}) {
  const { data: client } = useConnectorClient<Config>({ chainId })
  return useMemo(
    () => (client ? clientToSigner(client) : undefined),
    [client]
  )
}
```

**Usage:**
```typescript
import { useEthersSigner } from '@/hooks/useEthersSigner'
import { Safe, SafeApiKit } from '@safe-global/protocol-kit'

function MultiSigAction() {
  const signer = useEthersSigner()                // ← Pattern B hook
  const handlePropose = async () => {
    if (!signer) return
    const safe = await Safe.create({ ethAdapter: new EthersAdapter({ ethers, signerOrProvider: signer }), safeAddress })
    await safe.createTransaction(...)
  }
  return <button onClick={handlePropose}>Propose</button>
}
```

---

## Pattern C — ethers.js Provider → viem WalletClient (reverse bridge) {#pattern-c}

**When to use:** Headless Node.js scripts or test utilities that hold a pre-existing
ethers.js provider and need to bridge it into a viem context.
**⚠ Do NOT use in React frontend code** — use wagmi hooks there.

**File location:** `scripts/bridgeEthersToViem.ts`

```typescript
import { createWalletClient, custom } from 'viem'
import type { providers } from 'ethers'

/**
 * Bridges a legacy ethers.js Provider (v5 Web3Provider or v6 BrowserProvider)
 * into a viem WalletClient via its underlying EIP-1193 provider.
 *
 * Works with: ethers v5 Web3Provider, ethers v6 BrowserProvider, Hardhat provider,
 * any object exposing an EIP-1193 .request() method.
 *
 * Node.js / test utilities only — never call from React.
 */
export function bridgeEthersToViem(
  ethersProvider: providers.Web3Provider | { provider?: unknown; request?: unknown }
) {
  // v5: provider property holds the raw EIP-1193 object
  // v6 / direct EIP-1193: use the object itself
  const eip1193 =
    (ethersProvider as providers.Web3Provider).provider ?? ethersProvider

  return createWalletClient({
    transport: custom(eip1193 as Parameters<typeof custom>[0]),
  })
}
```

**Note:** For full WalletClient functionality (signing, sending) in Node.js scripts,
also pass `account` and `chain` to `createWalletClient`. Pure `JsonRpcProvider`
instances without an EIP-1193 `.request()` method do not support signing actions.

---

## Usage Matrix & Anti-Patterns {#usage-matrix}

### When to use each pattern

| Scenario | Pattern |
|---|---|
| Read-only SDK call (quotes, balances, simulations) | A: `clientToProvider` |
| State-changing SDK call (sign tx, create multisig) | B: `clientToSigner` |
| Node.js/test script bridging existing ethers instance | C: `bridgeEthersToViem` |
| Pure wagmi action (transfer, approve, mint) | None — use `useWriteContract` directly |

### Mandatory anti-patterns — never do these

```typescript
// ❌ Store Signer/Provider in React state
const [signer, setSigner] = useState<JsonRpcSigner>()
const [provider, setProvider] = useState<BrowserProvider>()

// ❌ Use deprecated ethers v5 class names
const provider = new ethers.providers.Web3Provider(window.ethereum)
const signer = provider.getSigner()

// ❌ Use ethers.BigNumber for any numeric value
const amount = ethers.BigNumber.from('1000000000000000000')
const gas = ethers.utils.parseEther('0.01')

// ❌ Use plain string for addresses
function transfer(to: string, amount: bigint) { ... }

// ✅ Correct: create adapter inline, scope to component, use BigInt + Address
import { type Address } from 'viem'

function MyComponent() {
  const signer = useEthersSigner()
  const handleClick = async () => {
    if (!signer) return
    const sdk = new ThirdPartySDK(signer)   // signer scoped here, not stored
    await sdk.execute({ amount: 1_000_000_000_000_000_000n })
  }
}

// ✅ Correct: typed addresses
function transfer(to: Address, amount: bigint) { ... }
```

---

*Last audited against wagmi v2 / viem v2 / ethers v6 — May 30, 2026.*
*Official reference: [wagmi.sh/react/guides/ethers](https://wagmi.sh/react/guides/ethers)*
