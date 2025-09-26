import "dotenv/config";

import { Foundry } from "@adraffy/blocksmith";
import { Contract, Interface, keccak256, toUtf8Bytes, AbiCoder, hexlify, getBytes } from "ethers";
import { strict as assert } from "node:assert";

const SEPOLIA_RPC = process.env.SEPOLIA_RPC_URL || "https://ethereum-sepolia.publicnode.com";

const LABEL = "base";
const LABEL_HASH = keccak256(toUtf8Bytes(LABEL));
const CHAIN_ID = "0x" + "21".repeat(32); // 32-byte hex (0x2121...)
const CHAIN_NAME = "base";

const IFACE = new Interface([
  "function text(bytes32,string) view returns (string)",
  "function data(bytes32,bytes) view returns (bytes)",
]);

const foundry = await Foundry.launch({ fork: SEPOLIA_RPC, procLog: false, infoLog: false });

try {
  const registry = await foundry.deploy<Contract>({ file: "ChainRegistry", args: [ (foundry as any).wallets?.admin?.address || "0x0000000000000000000000000000000000000001" ] });

  // register registry: LABEL -> CHAIN_ID (32-byte)
  await foundry.confirm(registry.register(LABEL, (foundry as any).wallets?.admin?.address || "0x0000000000000000000000000000000000000001", CHAIN_ID), { silent: true });

  const reverse = await foundry.deploy<Contract>({ file: "ReverseChainResolver", args: [registry.target] });

  // name: root (0x00) — minimal DNS bytes
  const DNS_NAME = new Uint8Array([0]);

  // resolve via text("chain-name:0x..")
  {
    const raw = Buffer.from(getBytes(CHAIN_ID)).toString("utf8");
    const key = `chain-name:${raw}`;
    const call = IFACE.encodeFunctionData("text(bytes32,string)", [LABEL_HASH, key]);
    const answer: string = await reverse.resolve(DNS_NAME, call);
    const [decoded] = IFACE.decodeFunctionResult("text(bytes32,string)", answer);
    assert.equal(decoded, CHAIN_NAME, "reverse text() did not return expected chain name");
  }

  // resolve via data("chain-name:0x..")
  {
    const prefix = AbiCoder.defaultAbiCoder().encode(["string"], ["chain-name:"]);
    const keyBytes = hexlify(new Uint8Array([...getBytes(prefix), ...getBytes(CHAIN_ID)]));
    const call = IFACE.encodeFunctionData("data(bytes32,bytes)", [LABEL_HASH, keyBytes]);
    const answer: string = await reverse.resolve(DNS_NAME, call);
    const [encoded] = IFACE.decodeFunctionResult("data(bytes32,bytes)", answer);
    let name: string;
    try {
      [name] = AbiCoder.defaultAbiCoder().decode(["string"], encoded);
    } catch {
      const hex = (encoded as string).replace(/^0x/, "");
      name = Buffer.from(hex, "hex").toString("utf8");
    }

    // chainId (hex) -> label
    console.log(`${CHAIN_ID} -> ${name}`);
    assert.equal(name, CHAIN_NAME, "reverse data() did not return expected chain name");
  }
} finally {
  await foundry.shutdown();
}
