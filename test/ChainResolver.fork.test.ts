import "dotenv/config";

import { Foundry } from "@adraffy/blocksmith";
import { Contract, concat, namehash, toBeHex, keccak256 } from "ethers";
import { strict as assert } from "node:assert";

const ENS_REGISTRY = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
const TEST_NAME = "cid.eth";
const NODE = namehash(TEST_NAME);

const SEPOLIA_RPC =
  process.env.SEPOLIA_RPC_URL || "https://ethereum-sepolia.publicnode.com";

function solidityFollowSlot(slot: bigint, keyHex: string): bigint {
  const hashed = keccak256(concat([keyHex, toBeHex(slot, 32)]));
  return BigInt(hashed);
}

function nodeSlot(nodeHex: string): bigint {
  // ENS Registry stores records in mapping(bytes32 => Record) at slot 0.
  // Resolver lives at offset +1 within the Record struct.
  const base = solidityFollowSlot(0n, nodeHex);
  return base + 1n;
}

const foundry = await Foundry.launch({
  fork: SEPOLIA_RPC,
  procLog: false,
  infoLog: true,
});

try {
  const chainResolver = await foundry.deploy<Contract>({
    file: "ChainResolver",
    args: [],
  });

  const chainIdKey: bigint = await chainResolver.CHAIN_ID_KEY();
  const payload = toBeHex(8453n, 32); // sample chain data payload

  await foundry.confirm(chainResolver.setAddr(NODE, chainIdKey, payload));

  // Verify direct contract reads
  const storedBytes: string = await chainResolver.addr(NODE, chainIdKey);
  assert.equal(storedBytes, payload, "stored payload mismatch");

  const reverseNode: string = await chainResolver.node(payload);
  assert.equal(
    reverseNode.toLowerCase(),
    NODE.toLowerCase(),
    "reverse lookup failed"
  );

  // Point ENS registry at our resolver for the test node by mutating storage
  const slot = nodeSlot(NODE);
  await foundry.provider.send("anvil_setStorageAt", [
    ENS_REGISTRY,
    toBeHex(slot, 32),
    toBeHex(BigInt(chainResolver.target), 32),
  ]);

  const ens = new Contract(
    ENS_REGISTRY,
    ["function resolver(bytes32 node) view returns (address)"],
    foundry.provider
  );

  const resolverAddress: string = await ens.resolver(NODE);
  assert.equal(
    resolverAddress.toLowerCase(),
    chainResolver.target.toLowerCase(),
    "ENS registry resolver not updated"
  );

  // Resolve via the registry-connected instance
  const resolverViaEns = new Contract(
    resolverAddress,
    [
      "function addr(bytes32 node, uint256 key) view returns (bytes)",
      "function node(bytes calldata data) view returns (bytes32)",
    ],
    foundry.provider
  );

  const bytesFromEns: string = await resolverViaEns.addr(NODE, chainIdKey);
  assert.equal(
    bytesFromEns,
    payload,
    "addr via ENS returned unexpected payload"
  );

  const nodeFromEns: string = await resolverViaEns.node(payload);
  assert.equal(
    nodeFromEns.toLowerCase(),
    NODE.toLowerCase(),
    "reverse via ENS returned wrong node"
  );

  console.log("Resolved payload:", bytesFromEns);
  console.log("Reverse node:", nodeFromEns);
} finally {
  await foundry.shutdown();
}
