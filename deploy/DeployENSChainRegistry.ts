// Deploy ChainRegistry, ChainResolver, and ReverseChainResolver

import {
  initSmith,
  promptContinueOrExit,
  deployContract,
  verifyContract,
  shutdownSmith,
  constructorCheck,
  loadDeployment,
  askQuestion,
} from "./libs/utils.ts";

import { init } from "./libs/init.ts";

// Initialize deployment
const { chainId, privateKey } = await init();

//Launch blocksmith
const { deployerWallet, smith, rl } = await initSmith(
  typeof chainId === "number" ? chainId : Number(chainId),
  privateKey
);

const shouldBegin = await promptContinueOrExit(rl, "Start deployment? (y/n)");

if (shouldBegin) {
  // 1) ChainRegistry
  const registryName = "ChainRegistry";
  let registryAddress: string | undefined;
  try {
    const existing = await loadDeployment(chainId, registryName);
    const found = existing.target as string;
    const code = await deployerWallet.provider.getCode(found);
    if (code && code !== '0x') {
      const useExisting = await promptContinueOrExit(
        rl,
        `${registryName} found at ${found}. Use this? (y/n)`
      );
      if (useExisting) {
        registryAddress = found;
      } else {
        const input = (await askQuestion(rl, `Enter ${registryName} address to use (leave empty to deploy): `)).trim();
        if (input) registryAddress = input;
      }
    } else {
      console.log(`[Warn] ${registryName} deployment file exists but no code at ${found} on chain ${chainId}.`);
    }
  } catch (err: any) {
    if (err?.code !== "ENOENT") throw err;
  }

  if (!registryAddress) {
    const shouldDeployRegistry = await promptContinueOrExit(
      rl,
      `Deploy ${registryName}? (y/n)`
    );
    if (shouldDeployRegistry) {
      const args: any[] = [deployerWallet.address];
      const libs = {};
      const { contract, already } = await deployContract(
        smith,
        deployerWallet,
        registryName,
        args,
        libs,
        "[Registry]"
      );
      if (already) constructorCheck(contract.constructorArgs, args);
      registryAddress = contract.target;

      const shouldVerifyReg = await promptContinueOrExit(
        rl,
        `Verify ${registryName}? (y/n)`
      );
      if (shouldVerifyReg) {
        await verifyContract(
          chainId,
          contract,
          registryName,
          contract.constructorArgs,
          libs,
          smith
        );
      }
    }
  }

  if (!registryAddress) {
    console.log("No ChainRegistry address available; cannot continue.");
  } else {
    // 2) ChainResolver
    const resolverName = "ChainResolver";
    let resolverAddress: string | undefined;
    try {
      const existingResolver = await loadDeployment(chainId, resolverName);
      const found = existingResolver.target as string;
      const code = await deployerWallet.provider.getCode(found);
      if (code && code !== '0x') {
        const useExisting = await promptContinueOrExit(
          rl,
          `${resolverName} found at ${found}. Use this? (y/n)`
        );
        if (useExisting) {
          resolverAddress = found;
        } else {
          const input = (await askQuestion(rl, `Enter ${resolverName} address to use (leave empty to deploy): `)).trim();
          if (input) resolverAddress = input;
        }
      } else {
        console.log(`[Warn] ${resolverName} deployment file exists but no code at ${found} on chain ${chainId}.`);
      }
    } catch (err: any) {
      if (err?.code !== "ENOENT") throw err;
    }

    if (!resolverAddress) {
      const shouldDeployResolver = await promptContinueOrExit(
        rl,
        `Deploy ${resolverName}? (y/n)`
      );

      if (shouldDeployResolver) {
        const args: any[] = [registryAddress];
        const libs = {};
        const { contract, already } = await deployContract(
          smith,
          deployerWallet,
          resolverName,
          args,
          libs,
          "[Resolver]"
        );
        if (already) constructorCheck(contract.constructorArgs, args);

        const shouldVerifyRes = await promptContinueOrExit(
          rl,
          `Verify ${resolverName}? (y/n)`
        );
        if (shouldVerifyRes) {
          await verifyContract(
            chainId,
            contract,
            resolverName,
            contract.constructorArgs,
            libs,
            smith
          );
        }
      }
    }

    // 3) ReverseChainResolver
    const reverseName = "ReverseChainResolver";
    let reverseAddress: string | undefined;
    try {
      const existingReverse = await loadDeployment(chainId, reverseName);
      const found = existingReverse.target as string;
      const code = await deployerWallet.provider.getCode(found);
      if (code && code !== '0x') {
        const useExisting = await promptContinueOrExit(
          rl,
          `${reverseName} found at ${found}. Use this? (y/n)`
        );
        if (useExisting) {
          reverseAddress = found;
        } else {
          const input = (await askQuestion(rl, `Enter ${reverseName} address to use (leave empty to deploy): `)).trim();
          if (input) reverseAddress = input;
        }
      } else {
        console.log(`[Warn] ${reverseName} deployment file exists but no code at ${found} on chain ${chainId}.`);
      }
    } catch (err: any) {
      if (err?.code !== "ENOENT") throw err;
    }

    if (!reverseAddress) {
      const shouldDeployReverse = await promptContinueOrExit(
        rl,
        `Deploy ${reverseName}? (y/n)`
      );

      if (shouldDeployReverse) {
        const args: any[] = [registryAddress];
        const libs = {};
        const { contract, already } = await deployContract(
          smith,
          deployerWallet,
          reverseName,
          args,
          libs,
          "[Reverse]"
        );
        if (already) constructorCheck(contract.constructorArgs, args);

        const shouldVerifyRev = await promptContinueOrExit(
          rl,
          `Verify ${reverseName}? (y/n)`
        );
        if (shouldVerifyRev) {
          await verifyContract(
            chainId,
            contract,
            reverseName,
            contract.constructorArgs,
            libs,
            smith
          );
        }
      }
    }
  }
}

//Shutdown
await shutdownSmith(rl, smith);
