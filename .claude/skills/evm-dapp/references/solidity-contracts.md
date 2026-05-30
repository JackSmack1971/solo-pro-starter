# Solidity Contracts & Foundry Reference

## Table of Contents
1. [Monorepo Contract Layout](#layout)
2. [foundry.toml Configuration](#config)
3. [Core forge Commands](#commands)
4. [ABI Export Pipeline](#abi-export)
5. [Deployment with forge script](#deployment)
6. [Testing Patterns](#testing)
7. [Solidity Version & Style Rules](#style)

---

## Monorepo Contract Layout {#layout}

```
packages/contracts/
├── foundry.toml             ← Foundry project config
├── src/
│   └── MyContract.sol       ← Contract source (solc >= 0.8.35)
├── test/
│   └── MyContract.t.sol     ← Unit + fuzz tests
├── script/
│   └── Deploy.s.sol         ← Deployment broadcast script
├── lib/                     ← forge install dependencies (gitignored content)
│   └── forge-std/
└── out/                     ← forge build artifacts (gitignored)
    └── MyContract.sol/
        └── MyContract.json  ← Contains ABI array for export
```

---

## foundry.toml Configuration {#config}

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
test = "test"
script = "script"
optimizer = true
optimizer_runs = 200
solc_version = "0.8.35"          # ← current stable; pin explicitly in monorepos
evm_version = "cancun"
via_ir = false                   # set true only if needed (longer compile time)
bytecode_hash = "ipfs"
cbor_metadata = true
auto_detect_solc = false         # explicit pinning prevents silent version drift
ffi = false                      # disable unless explicitly required

[profile.ci]
fuzz = { runs = 10_000 }
invariant = { runs = 256 }

[fmt]
line_length = 100
sort_imports = true

[lint]
# see `forge lint --help` for available rules

[rpc_endpoints]
mainnet  = "${MAINNET_RPC_URL}"
sepolia  = "${SEPOLIA_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
local    = "http://127.0.0.1:8545"

[etherscan]
mainnet  = { key = "${ETHERSCAN_API_KEY}", url = "https://api.etherscan.io/api" }
sepolia  = { key = "${ETHERSCAN_API_KEY}", url = "https://api-sepolia.etherscan.io/api" }
arbitrum = { key = "${ARBISCAN_API_KEY}",  url = "https://api.arbiscan.io/api" }
```

All RPC URLs and API keys come from environment variables. Never hardcode.

---

## Core forge Commands {#commands}

```bash
# Build all contracts
forge build

# Run all tests
forge test -vvv

# Run specific test by name
forge test --match-test "test_Transfer" -vvv

# Run fuzz tests with increased runs
forge test --match-test "testFuzz" --fuzz-runs 10000

# Check gas usage
forge test --gas-report

# Format all Solidity files
forge fmt

# Verify formatting without modifying files (CI gate)
forge fmt --check

# Built-in static analysis (Foundry v0.3+)
forge lint

# Inspect storage layout (critical before any upgrade)
forge inspect MyContract storageLayout

# Deep static analysis (optional; forge lint covers most common patterns)
# slither . --config-file slither.config.json

# Get ABI for a deployed contract via cast
cast abi-decode "balanceOf(address)(uint256)" <calldata>
```

---

## ABI Export Pipeline {#abi-export}

The `scripts/export-abis.sh` skill script automates this. Run it after every `forge build`:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/export-abis.sh"
```

Manual export pattern (when script is unavailable):
```bash
# Extract ABI from forge build artifact
jq '.abi' out/MyContract.sol/MyContract.json

# Write as TypeScript const (pipe result into file)
echo "// Auto-generated from forge build. Do not edit." > apps/web/src/abis/MyContract.ts
echo "export const MY_CONTRACT_ABI = $(jq '.abi' out/MyContract.sol/MyContract.json) as const" \
  >> apps/web/src/abis/MyContract.ts
```

**Key rule:** Always append `as const` — without it, viem cannot infer function signatures.

---

## Deployment with forge script {#deployment}

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Script, console } from "forge-std/Script.sol";
import { MyContract } from "../src/MyContract.sol";

contract DeployScript is Script {
    function run() external {
        // Option A (env key — works but discouraged in production)
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // Option B (preferred): omit the key here and pass --account or --ledger at CLI
        // vm.startBroadcast();

        MyContract deployed = new MyContract();
        console.log("Deployed:", address(deployed));

        vm.stopBroadcast();
    }
}
```

```bash
# Dry run (no broadcast)
forge script script/Deploy.s.sol --rpc-url sepolia

# Broadcast + verify on Sepolia (env key — development only)
forge script script/Deploy.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  --etherscan-api-key "${ETHERSCAN_API_KEY}"

# Preferred production pattern: Foundry keystore (no key in environment)
forge script script/Deploy.s.sol \
  --rpc-url sepolia \
  --account my-deployer \
  --broadcast \
  --verify

# Broadcast to local Anvil (no verification)
# Alias requires [rpc_endpoints] local in foundry.toml; use explicit URL as fallback:
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

**Security:** Never log, print, or commit private keys. For production deployments use
`forge script --account <name>` (Foundry keystore) or `--ledger` (hardware wallet)
instead of raw `DEPLOYER_PRIVATE_KEY` environment variables.

---

## Testing Patterns {#testing}

```solidity
// test/MyContract.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Test, console } from "forge-std/Test.sol";
import { MyContract } from "../src/MyContract.sol";

contract MyContractTest is Test {
    MyContract public target;
    address public alice = makeAddr("alice");   // deterministic test address

    function setUp() public {
        target = new MyContract();
        deal(alice, 1 ether);                   // fund test address
    }

    // Unit test
    function test_Transfer() public {
        uint256 amount = 100;
        vm.prank(alice);
        bool ok = target.transfer(address(this), amount);
        assertTrue(ok, "transfer should return true");
        assertEq(target.balanceOf(address(this)), amount);
    }

    // Fuzz test — Foundry generates random inputs
    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, target.balanceOf(alice));
        vm.prank(alice);
        bool ok = target.transfer(address(this), amount);
        assertTrue(ok);
    }

    // Revert test
    function test_RevertWhen_InsufficientBalance() public {
        uint256 tooMuch = target.balanceOf(alice) + 1;
        vm.prank(alice);
        vm.expectRevert();
        target.transfer(address(this), tooMuch);
    }

    // Event test
    function test_EmitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, address(this), 100);   // declare expected event first
        vm.prank(alice);
        target.transfer(address(this), 100);
    }
}

// Invariant test contract (separate file or nested)
// Run with: forge test --invariant
contract MyContractInvariantTest is Test {
    MyContract public target;

    function setUp() public {
        target = new MyContract();
    }

    // Invariant: total supply must never exceed the cap
    function invariant_totalSupplyNeverExceedsCap() public view {
        assertLe(target.totalSupply(), target.cap());
    }
}
```

---

## Solidity Version & Style Rules {#style}

- Minimum version: `pragma solidity ^0.8.35;` (current stable; see `solc_version` in foundry.toml)
- All contracts must include `// SPDX-License-Identifier: MIT` (or appropriate license)
- Use `custom error` declarations instead of `require(condition, "string")` (saves gas)
- Use `unchecked { }` blocks only where overflow is mathematically impossible
- Never use `tx.origin` for authorization — always `msg.sender`
- Emit events for all state-changing operations (enables viem `watchContractEvent`)
- Mark functions that do not modify state as `view` or `pure`
- Run `forge fmt` before every commit; enforce in CI with `forge fmt --check`
- Ordering within a file: imports → custom errors → events → state variables → modifiers → functions
