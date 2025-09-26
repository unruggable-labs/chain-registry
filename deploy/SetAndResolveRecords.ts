// Set records for a label and immediately resolve them via ENSIP-10
import 'dotenv/config'

import { init } from './libs/init.ts';
import {
  initSmith,
  shutdownSmith,
  loadDeployment,
  askQuestion,
  promptContinueOrExit,
} from './libs/utils.ts';

import {
  Contract,
  Interface,
  dnsEncode,
  keccak256,
  toUtf8Bytes,
  isHexString,
  hexlify,
} from 'ethers';

function toBytesLike(input: string): string {
  if (!input) return '0x';
  if (isHexString(input)) return input;
  return hexlify(toUtf8Bytes(input));
}

// Initialize context
const { chainId, privateKey } = await init();
const { deployerWallet, smith, rl } = await initSmith(
  typeof chainId === 'number' ? chainId : Number(chainId),
  privateKey,
);

try {
  // Locate ChainResolver
  let resolverAddress: string | undefined;
  try {
    const res = await loadDeployment(chainId, 'ChainResolver');
    const found = res.target as string;
    const code = await deployerWallet.provider.getCode(found);
    if (code && code !== '0x') resolverAddress = found;
  } catch {}
  if (!resolverAddress) {
    const envRes = (process.env.CHAIN_RESOLVER_ADDRESS || process.env.RESOLVER_ADDRESS || '').trim();
    if (envRes) resolverAddress = envRes;
  }
  if (!resolverAddress) resolverAddress = (await askQuestion(rl, 'ChainResolver address: ')).trim();
  if (!resolverAddress) {
    console.error('ChainResolver address is required.');
    process.exit(1);
  }

  // Contracts & ABIs
  const resolver = new Contract(
    resolverAddress!,
    [
      'function resolve(bytes name, bytes data) view returns (bytes)',
      'function setAddr(bytes32,uint256,address) external',
      'function setContenthash(bytes32,bytes) external',
      'function setText(bytes32,string,string) external',
      'function setData(bytes32,bytes,bytes) external',
    ],
    deployerWallet,
  );

  const IFACE = new Interface([
    'function addr(bytes32) view returns (address)',
    'function addr(bytes32,uint256) view returns (address)',
    'function contenthash(bytes32) view returns (bytes)',
    'function text(bytes32,string) view returns (string)',
    'function data(bytes32,bytes) view returns (bytes)',
  ]);

  // Input label
  const label = (await askQuestion(rl, 'Label (e.g. base): ')).trim();
  if (!label) {
    console.error('Label is required.');
    process.exit(1);
  }
  const labelHash = keccak256(toUtf8Bytes(label));
  const ensName = `${label}.cid.eth`;
  const dnsName = dnsEncode(ensName, 255);
  console.log('Using:', { ensName, labelHash });

  async function resolveDecode<T = any>(sig: string, args: any[]): Promise<T> {
    const call = IFACE.encodeFunctionData(sig, args);
    const answer: string = await resolver.resolve(dnsName, call);
    const [decoded] = IFACE.decodeFunctionResult(sig, answer);
    return decoded as T;
  }

  // Set addr(60)
  if (await promptContinueOrExit(rl, 'Set addr(60)? (y/n): ')) {
    const a60 = (await askQuestion(rl, 'ETH address: ')).trim();
    const tx = await resolver.setAddr(labelHash, 60, a60);
    await tx.wait();
    const resolved = await resolveDecode<string>('addr(bytes32)', [labelHash]);
    console.log('✓ addr(60) =', resolved);
  }

  // Set addr with custom coinType
  if (await promptContinueOrExit(rl, 'Set addr(label, coinType)? (y/n): ')) {
    const coinTypeStr = (await askQuestion(rl, 'coinType (uint): ')).trim();
    const coinType = BigInt(coinTypeStr);
    const addr = (await askQuestion(rl, 'address: ')).trim();
    const tx = await resolver.setAddr(labelHash, coinType, addr);
    await tx.wait();
    const resolved = await resolveDecode<string>('addr(bytes32,uint256)', [labelHash, coinType]);
    console.log(`✓ addr(${coinType}) =`, resolved);
  }

  // Set contenthash
  if (await promptContinueOrExit(rl, 'Set contenthash? (y/n): ')) {
    const ch = (await askQuestion(rl, 'contenthash (0x..): ')).trim();
    const tx = await resolver.setContenthash(labelHash, ch);
    await tx.wait();
    const resolved = await resolveDecode<string>('contenthash(bytes32)', [labelHash]);
    console.log('✓ contenthash =', resolved);
  }

  // Set text(key,value)
  if (await promptContinueOrExit(rl, "Set text(key,value)? (y/n): ")) {
    const key = (await askQuestion(rl, 'text key: ')).trim();
    const val = (await askQuestion(rl, 'text value: ')).trim();
    const tx = await resolver.setText(labelHash, key, val);
    await tx.wait();
    const resolved = await resolveDecode<string>('text(bytes32,string)', [labelHash, key]);
    console.log(`✓ text(${key}) =`, resolved);
  }

  // Set data(keyBytes,valueBytes)
  if (await promptContinueOrExit(rl, 'Set data(keyBytes,valueBytes)? (y/n): ')) {
    const k = (await askQuestion(rl, 'data key (utf8 or 0x..): ')).trim();
    const v = (await askQuestion(rl, 'data value (utf8 or 0x..): ')).trim();
    const keyBytes = toBytesLike(k);
    const valBytes = toBytesLike(v);
    const tx = await resolver.setData(labelHash, keyBytes, valBytes);
    await tx.wait();
    const resolved = await resolveDecode<string>('data(bytes32,bytes)', [labelHash, keyBytes]);
    console.log('✓ data =', resolved);
  }

  console.log('Done.');
} finally {
  await shutdownSmith(rl, smith);
}

