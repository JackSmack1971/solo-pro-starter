# Local Development Node Reference

## Table of Contents
1. [Anvil — Primary Local Node](#anvil)
2. [wagmi Chain Config for Local](#wagmi-local)
3. [Funded Test Accounts](#accounts)
4. [Fork Mode (Mainnet / L2 Forking)](#fork-mode)
5. [Deploy & Test Against Anvil](#deploy-test)
6. [Docker Compose (Advanced / L2-Specific)](#docker)

---

## Anvil — Primary Local Node {#anvil}

Anvil ships with Foundry. No extra installation required.
This is the primary local node for all EVM chains. Docker is only needed for chain-specific
binary requirements (e.g., Arbitrum Stylus WASM execution).

```bash
# Basic startup — 10 funded accounts, 10,000 ETH each (official default), chainId 31337
anvil

# Custom chain ID (prevents MetaMask cache collisions between projects)
anvil --chain-id 31337 --block-time 2

# Persist state across restarts
anvil --state /tmp/anvil-state.json

# Quiet mode (minimal output, useful in CI) — flag is --quiet / -q, not --silent
anvil --quiet &
```

Default RPC endpoint: `http://127.0.0.1:8545`
Default chain ID: `31337` (matches wagmi's built-in `foundry` chain)

---

## wagmi Chain Config for Local {#wagmi-local}

wagmi ships a `foundry` chain (chainId 31337) — no custom chain definition needed.

```typescript
// src/wagmi.config.ts — local dev branch
import { http, createConfig } from 'wagmi'
import { foundry, mainnet, sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

const isDev = process.env.NODE_ENV === 'development'

export const wagmiConfig = createConfig({
  chains: isDev ? [foundry, sepolia, mainnet] : [mainnet, sepolia],
  connectors: [injected()],
  transports: {
    [foundry.id]: http('http://127.0.0.1:8545'),
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
  ssr: true,
})
```

To connect MetaMask to Anvil:
- Network name: `Foundry Local`
- RPC URL: `http://127.0.0.1:8545`
- Chain ID: `31337`
- Currency: `ETH`

---

## Funded Test Accounts {#accounts}

Anvil prints 10 private keys at startup. Account #0 is the default deployer.

```
Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

```bash
# Import Anvil account #0 into cast wallet
cast wallet import anvil-dev \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Send ETH from account #0 to a test address
cast send 0xYourAddress \
  --value 1ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://127.0.0.1:8545

# Check balance
cast balance 0xYourAddress --rpc-url http://127.0.0.1:8545
```

**Security:** These private keys are publicly known. Safe **only** for local Anvil.
Never use them on Sepolia, mainnet, or any live network.

**Note:** Anvil funds each account with 10,000 ETH by default (`--balance 10000`).
Override with `anvil --balance 1000` to simulate realistic mainnet scarcity in tests.

---

## Fork Mode — Mainnet / L2 Forking {#fork-mode}

Fork mode creates a local replica of live chain state. Contracts and balances are read
from the live RPC at the specified block, enabling integration testing without spending gas.

```bash
# Fork Ethereum mainnet at latest block
anvil --fork-url "${MAINNET_RPC_URL}"

# Fork at a specific block (deterministic: same block = same state)
anvil --fork-url "${MAINNET_RPC_URL}" --fork-block-number 19_000_000

# Fork Arbitrum One (retains chainId 42161)
anvil --fork-url "${ARBITRUM_RPC_URL}" --chain-id 42161

# Fork Base
anvil --fork-url "${BASE_RPC_URL}" --chain-id 8453
```

**Forge test with fork:**
```solidity
contract MyForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 19_000_000);
    }

    function test_UsdcBalance() public {
        // Real USDC contract state at block 19_000_000
        uint256 bal = IERC20(USDC).balanceOf(address(this));
        assertEq(bal, 0);
    }
}
```

---

## Deploy & Test Against Anvil {#deploy-test}

Standard development loop:

```bash
# Terminal 1: start Anvil
anvil --chain-id 31337 --block-time 1

# Terminal 2: compile and deploy
forge build
# Requires [rpc_endpoints] local = "http://127.0.0.1:8545" in foundry.toml (see solidity-contracts.md)
# or use the explicit URL to bypass the alias:
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# Interact via cast
cast call <DEPLOYED_ADDRESS> "balanceOf(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://127.0.0.1:8545

# Terminal 3: run Next.js frontend
pnpm --filter web dev
```

After deploy, copy the printed contract address into `.env.local`:
```bash
NEXT_PUBLIC_CONTRACT_ADDRESS=0x...
```

---

## Docker Compose (Advanced / L2-Specific) {#docker}

Only required when the project uses chain-specific execution environments
(e.g., Arbitrum Stylus WASM contracts that Anvil cannot emulate).

```yaml
# docker-compose.yml
services:
  devnode:
    image: offchainlabs/nitro-node:latest
    ports:
      - "8547:8547"
      - "8548:8548"
    volumes:
      - ./devnode-data:/workspace
    command:
      - --init.empty
      - --node.dangerous.no-l1-listener
      - --chain.id=412346
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8547"]
      interval: 5s
      timeout: 3s
      retries: 15
```

```bash
# Start devnode
docker compose up -d devnode

# Wait for health, then deploy
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8547 --broadcast

# wagmi transport for Arbitrum devnode
[arbitrumNitroLocal.id]: http('http://127.0.0.1:8547')
```

For standard EVM chains: **use Anvil, not Docker**. Docker adds setup overhead with no benefit
unless Stylus/WASM contract execution is required.
