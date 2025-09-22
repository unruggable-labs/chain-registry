/**
 * @description This script deploys the ChainResolver contract, and verifies it on Etherscan.
 * @usage       bun run deploy/DeployChainResolver.ts --chain=sepolia
 * @author      @unruggable-labs
 * @date        2025-08-22
 */

import {
  initSmith,
  promptContinueOrExit,
  deployContract,
  verifyContract,
  shutdownSmith,
  constructorCheck,
  loadDeployment,
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
  const contractName = "ChainResolver";

  let existingResolver;
  try {
    existingResolver = await loadDeployment(chainId, contractName);
    console.log(
      `${contractName} already deployed at ${existingResolver.target}.`
    );
  } catch (err: any) {
    if (err?.code !== "ENOENT") {
      throw err;
    }
  }

  const shouldDeployContract = await promptContinueOrExit(
    rl,
    `Deploy ${contractName}? (y/n)`
  );

  let deployedContract;
  if (shouldDeployContract) {
    const contractArgs: any[] = [];
    const contractLibs = {};

    const { contract, already } = await deployContract(
      smith,
      deployerWallet,
      contractName,
      contractArgs,
      contractLibs
    );

    deployedContract = contract;

    if (already)
      constructorCheck(deployedContract.constructorArgs, contractArgs);

    const shouldVerify = await promptContinueOrExit(
      rl,
      `Verify ${contractName}? (y/n)`
    );

    if (shouldVerify && deployedContract) {
      await verifyContract(
        chainId,
        deployedContract,
        contractName,
        deployedContract.constructorArgs,
        contractLibs,
        smith
      );
    }
  }
}

//Shutdown
await shutdownSmith(rl, smith);
