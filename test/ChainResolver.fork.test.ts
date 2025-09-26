import "dotenv/config";

import { Foundry } from "@adraffy/blocksmith";
import {
  Contract,
  Interface,
  dnsEncode,
  keccak256,
  toUtf8Bytes,
} from "ethers";
import { strict as assert } from "node:assert";

const SEPOLIA_RPC =
  process.env.SEPOLIA_RPC_URL || "https://ethereum-sepolia.publicnode.com";

const LABEL = "optimism";
const LABEL_HASH = keccak256(toUtf8Bytes(LABEL));
const DNS_NAME = dnsEncode(`${LABEL}.cid.eth`, 255);

const RESOLVER_IFACE = new Interface([
  "function addr(bytes32) view returns (address)",
  "function addr(bytes32,uint256) view returns (address)",
  "function contenthash(bytes32) view returns (bytes)",
  "function text(bytes32,string) view returns (string)",
  "function data(bytes32,bytes) view returns (bytes)",
]);

const foundry = await Foundry.launch({
  fork: SEPOLIA_RPC,
  procLog: false,
  infoLog: false,
});

try {
  const registry = await foundry.deploy<Contract>({
    file: "ChainRegistry",
    args: [ (foundry as any).wallets?.admin?.address ?? '0x0000000000000000000000000000000000000001' ],
  });

  const chainResolver = await foundry.deploy<Contract>({
    file: "ChainResolver",
    args: [registry.target],
  });

  // register registry: LABEL -> CHAIN_ID (32-byte)
  const CHAIN_ID = "0x" + "21".repeat(32);
  await foundry.confirm(
    registry.register(LABEL, "0x0000000000000000000000000000000000000000", CHAIN_ID),
    { silent: true }
  );

  // register resolver: labelhash owner
  await foundry.confirm(
    chainResolver.register(LABEL_HASH, "0x0000000000000000000000000000000000000000"),
    { silent: true }
  );
  {
    // resolve via text("chain-id")
    const call = RESOLVER_IFACE.encodeFunctionData("text(bytes32,string)", [
      LABEL_HASH,
      "chain-id",
    ]);
    const answer: string = await chainResolver.resolve(DNS_NAME, call);
    const [decoded] = RESOLVER_IFACE.decodeFunctionResult(
      "text(bytes32,string)",
      answer
    );
    const expectedNo0x = CHAIN_ID.replace(/^0x/, "").toLowerCase();
    assert.equal(decoded.toLowerCase(), expectedNo0x, "text(chain-id) mismatch");
    console.log(`${LABEL} -> 0x${decoded}`);
  }

  
  {
    // resolve via data("chain-id")
    const key = new TextEncoder().encode("chain-id");
    const call = RESOLVER_IFACE.encodeFunctionData("data(bytes32,bytes)", [
      LABEL_HASH,
      key,
    ]);
    const answer: string = await chainResolver.resolve(DNS_NAME, call);
    assert.equal(answer.toLowerCase(), CHAIN_ID.toLowerCase(), "data(chain-id) mismatch");
  }
} finally {
  await foundry.shutdown();
}
