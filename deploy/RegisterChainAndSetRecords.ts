// Register a chain in ChainRegistry and optionally set ChainResolver records
import 'dotenv/config'

import { init } from "./libs/init.ts";
import {
  initSmith,
  shutdownSmith,
  loadDeployment,
  askQuestion,
  promptContinueOrExit,
} from "./libs/utils.ts";
import {
  Contract,
  Interface,
  keccak256,
  toUtf8Bytes,
  toBeHex,
  isHexString,
  hexlify,
} from "ethers";

function toBytesLike(input: string): string {
  if (!input) return "0x";
  if (isHexString(input)) return input;
  return hexlify(toUtf8Bytes(input));
}

const { chainId, privateKey } = await init();
const { deployerWallet, smith, rl } = await initSmith(
  typeof chainId === "number" ? chainId : Number(chainId),
  privateKey
);

try {
  // Resolve contract addresses (env > deployments > prompt)
  let registryAddress: string | undefined;
  let resolverAddress: string | undefined;

  // 0) Prefer explicit env var for ChainRegistry
  try {
    const envReg = (process.env.CHAIN_REGISTRY_ADDRESS || "").trim();
    if (envReg) {
      const code = await deployerWallet.provider.getCode(envReg);
      if (code && code !== "0x") registryAddress = envReg;
    }
  } catch {}

  try {
    const reg = await loadDeployment(chainId, "ChainRegistry");
    const found = reg.target as string;
    const code = await deployerWallet.provider.getCode(found);
    if (code && code !== "0x") registryAddress = found;
  } catch {}
  // 0b) Prefer explicit env var for ChainResolver
  try {
    const envRes = (process.env.CHAIN_RESOLVER_ADDRESS || "").trim();
    if (envRes) {
      const code = await deployerWallet.provider.getCode(envRes);
      if (code && code !== "0x") resolverAddress = envRes;
    }
  } catch {}
  try {
    const res = await loadDeployment(chainId, "ChainResolver");
    const found = res.target as string;
    const code = await deployerWallet.provider.getCode(found);
    if (code && code !== "0x") resolverAddress = found;
  } catch {}

  if (!registryAddress) registryAddress = (await askQuestion(rl, "ChainRegistry address: ")).trim();
  if (!resolverAddress) resolverAddress = (await askQuestion(rl, "ChainResolver address: ")).trim();
  if (!registryAddress || !resolverAddress) {
    console.error("ChainRegistry and ChainResolver addresses are required.");
    process.exit(1);
  }

  const registry = new Contract(
    registryAddress,
    [
      "function register(string,address,bytes) external",
      "function chainId(bytes32) view returns (bytes)",
      "function chainName(bytes) view returns (string)",
    ],
    deployerWallet
  );

  const resolver = new Contract(
    resolverAddress,
    [
      "function register(bytes32,address) external",
      "function setAddr(bytes32,uint256,address) external",
      "function setContenthash(bytes32,bytes) external",
      "function setText(bytes32,string,string) external",
      "function setData(bytes32,bytes,bytes) external",
    ],
    deployerWallet
  );

  // Inputs
  const label = (await askQuestion(rl, "Chain label (e.g. optimism): ")).trim();
  const labelHash = keccak256(toUtf8Bytes(label));
  let cidIn = (await askQuestion(rl, "Chain ID (hex 0x.. or decimal): ")).trim();
  if (!isHexString(cidIn)) cidIn = toBeHex(BigInt(cidIn));
  const ownerIn = (await askQuestion(rl, `Owner [default ${deployerWallet.address}]: `)).trim();
  const owner = ownerIn || deployerWallet.address;

  // Register in registry and resolver
  console.log("Registering in ChainRegistry...");
  let ok = await promptContinueOrExit(rl, "Proceed? (y/n): ");
  if (ok) {
    try {
      const tx = await registry.register(label, owner, cidIn);
      await tx.wait();
      console.log("✓ registry.register");
    } catch (e: any) {
      const errIface = new Interface([
        "error LabelAlreadyRegistered(bytes32)",
        "error NotAuthorized(address,bytes32)",
      ]);
      const data: string | undefined = e?.data || e?.error?.data || e?.info?.error?.data;
      let decoded = undefined as any;
      try { if (data && typeof data === 'string') decoded = errIface.parseError(data); } catch {}
      const short = e?.shortMessage || e?.message || "";
      if (decoded?.name === 'LabelAlreadyRegistered' || /LabelAlreadyRegistered/.test(short)) {
        console.log("✗ Label already registered:", label, "(skipping registry.register)");
      } else if (/Ownable: caller is not the owner|NotAuthorized/.test(short)) {
        console.log("✗ Not authorized to register this label (owner-only)");
      } else {
        console.error("✗ registry.register failed:", short);
      }
    }
  }

  console.log("Registering label in ChainResolver...");
  ok = await promptContinueOrExit(rl, "Proceed? (y/n): ");
  if (ok) {
    try {
      const tx = await resolver.register(labelHash, owner);
      await tx.wait();
      console.log("✓ resolver.register");
    } catch (e: any) {
      const errIface = new Interface(["error LabelAlreadyRegistered(bytes32)"]);
      const data: string | undefined = e?.data || e?.error?.data || e?.info?.error?.data;
      let decoded = undefined as any;
      try { if (data && typeof data === 'string') decoded = errIface.parseError(data); } catch {}
      const short = e?.shortMessage || e?.message || "";
      if (decoded?.name === 'LabelAlreadyRegistered' || /LabelAlreadyRegistered/.test(short)) {
        console.log("✗ Label already registered in resolver (skipping)");
      } else if (/Ownable: caller is not the owner/.test(short)) {
        console.log("✗ Not authorized to register label in resolver (owner-only)");
      } else {
        console.error("✗ resolver.register failed:", short);
      }
    }
  }

  // Quick sanity
  try {
    const cid = await registry.chainId(labelHash);
    const name = await registry.chainName(cid);
    console.log("chainId:", cid, "chainName:", name);
  } catch {}

  // Optional records
  console.log("\nOptional records: The following prompts are optional.");
  console.log("You can answer 'n' to skip any of them.\n");
  if (await promptContinueOrExit(rl, "Set addr(60)? (y/n): ")) {
    const a60 = (await askQuestion(rl, "ETH address: ")).trim();
    const tx = await resolver.setAddr(labelHash, 60, a60);
    await tx.wait();
    console.log("✓ setAddr(60)");
  }

  if (await promptContinueOrExit(rl, "Set another addr with custom coinType? (y/n): ")) {
    const ctStr = (await askQuestion(rl, "coinType (uint): ")).trim();
    const ct = BigInt(ctStr);
    const addr = (await askQuestion(rl, "address: ")).trim();
    const tx = await resolver.setAddr(labelHash, ct, addr);
    await tx.wait();
    console.log(`✓ setAddr(${ct})`);
  }

  if (await promptContinueOrExit(rl, "Set contenthash? (y/n): ")) {
    const ch = (await askQuestion(rl, "contenthash (0x..): ")).trim();
    const tx = await resolver.setContenthash(labelHash, ch);
    await tx.wait();
    console.log("✓ setContenthash");
  }

  if (await promptContinueOrExit(rl, "Set text('avatar')? (y/n): ")) {
    const url = (await askQuestion(rl, "avatar URL: ")).trim();
    const tx = await resolver.setText(labelHash, "avatar", url);
    await tx.wait();
    console.log("✓ setText(avatar)");
  }

  if (await promptContinueOrExit(rl, "Set arbitrary text(key,value)? (y/n): ")) {
    const key = (await askQuestion(rl, "text key: ")).trim();
    const val = (await askQuestion(rl, "text value: ")).trim();
    const tx = await resolver.setText(labelHash, key, val);
    await tx.wait();
    console.log(`✓ setText(${key})`);
  }

  if (await promptContinueOrExit(rl, "Set data(keyBytes,valueBytes)? (y/n): ")) {
    const k = (await askQuestion(rl, "data key (utf8 or 0x..): ")).trim();
    const v = (await askQuestion(rl, "data value (utf8 or 0x..): ")).trim();
    const keyBytes = toBytesLike(k);
    const valBytes = toBytesLike(v);
    const tx = await resolver.setData(labelHash, keyBytes, valBytes);
    await tx.wait();
    console.log("✓ setData");
  }

  console.log("Done.");
} finally {
  await shutdownSmith(rl, smith);
}
