// Reverse resolve a chainId to name via ReverseChainResolver (ENSIP-10)

import 'dotenv/config'
import { init } from "./libs/init.ts";
import { initSmith, shutdownSmith, loadDeployment, askQuestion } from "./libs/utils.ts";
import { Contract, Interface, AbiCoder, dnsEncode, getBytes, hexlify, isHexString } from "ethers";

const { chainId, privateKey } = await init();
const { deployerWallet, smith, rl } = await initSmith(
  typeof chainId === "number" ? chainId : Number(chainId),
  privateKey
);

try {
  // Locate ReverseChainResolver
  let reverseAddress: string | undefined;
  try {
    const res = await loadDeployment(chainId, "ReverseChainResolver");
    const found = res.target as string;
    const code = await deployerWallet.provider.getCode(found);
    if (code && code !== '0x') {
      reverseAddress = found;
    }
  } catch {}
  if (!reverseAddress) reverseAddress = process.env.REVERSE_RESOLVER_ADDRESS || "";
  if (!reverseAddress) reverseAddress = (await askQuestion(rl, "ReverseChainResolver address: ")).trim();
  if (!reverseAddress) {
    console.error("ReverseChainResolver address is required.");
    process.exit(1);
  }

  const reverse = new Contract(
    reverseAddress!,
    ["function resolve(bytes name, bytes data) view returns (bytes)"],
    deployerWallet
  );

  // Input chainId
  let cidIn = (await askQuestion(rl, "Chain ID (0x.. hex or decimal): ")).trim();
  if (!isHexString(cidIn)) {
    const n = BigInt(cidIn);
    // minimal bytes; hexlify will include 0x prefix
    cidIn = hexlify(n);
  }
  const chainIdBytes = getBytes(cidIn);

  // Build key for ReverseChainResolver data() path: abi.encode("chain-name:") || chainIdBytes
  // Build ENSIP-10 data() call: key = abi.encode("chain-name:") || chainIdBytes
  const IFACE = new Interface([
    "function data(bytes32,bytes) view returns (bytes)",
  ]);
  const prefix = AbiCoder.defaultAbiCoder().encode(["string"], ["chain-name:"]);
  const key = hexlify(new Uint8Array([...getBytes(prefix), ...chainIdBytes]));
  const dnsName = dnsEncode("x.cid.eth", 255);
  const ZERO_NODE = "0x" + "0".repeat(64);
  

  try {
    const call = IFACE.encodeFunctionData("data(bytes32,bytes)", [ZERO_NODE, key]);
    const answer: string = await reverse.resolve(dnsName, call);
    const [encoded] = IFACE.decodeFunctionResult("data(bytes32,bytes)", answer);
    let name: string;
    try {
      // Preferred: abi.encode(string)
      [name] = AbiCoder.defaultAbiCoder().decode(["string"], encoded);
    } catch {
      // Fallback: raw UTF-8 bytes
      const hex = (encoded as string).replace(/^0x/, "");
      name = Buffer.from(hex, "hex").toString("utf8");
    }
    // Print just Chainname and ChainId
    console.log('Chain name:', name);
    console.log('ENS name:', name + '.cid.eth');
  } catch (e) {
    console.error((e as Error).message);
    process.exit(1);
  }
} finally {
  await shutdownSmith(rl, smith);
}
