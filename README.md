# ChainResolver

Minimal ENS resolver that stores a single canonical `chain-id` record per node
according to the [ENSIP-TBD-9](https://github.com/nxt3d/ensips/blob/ensip-ideas/ensips/ensip-TBD-9.md) proposal. The resolver exposes:

- `addr(node, CHAIN_ID_KEY)` → `bytes` (chain identifier payload)
- `setAddr(node, CHAIN_ID_KEY, data)` for owner-only updates
- `node(data)` → `bytes32` reverse mapping lookup keyed by the hashed payload

`CHAIN_ID_KEY` is the deterministic value derived from `keyGen("chain-id")` where keyGen() is defined as:

```solidity
function keyGen(string memory x) pure returns (uint256) {
    return (uint256(keccak256(bytes(x))) - 1) << 32;
}
```

## Development

```bash
forge install
forge test
bun install
```

### Sepolia Integration test

```bash
bun run test/ChainResolver.fork.test.ts 
```

Requires a Sepolia RPC URL in `.env` (`SEPOLIA_RPC_URL`); if unset the test
falls back to a default RPC endpoint.

## Deployment

```bash
bun run deploy/DeployChainResolver.ts --chain=<chain-name>
```

Where:

```
<chain-name> = "mainnet" | "sepolia"
```

Configure `.env` for the appropriate RPC and private key.
