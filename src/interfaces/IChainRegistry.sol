// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IChainRegistry
 * @author @defi-wonderland
 * @notice Interface for the ChainRegistry (formerly L2Resolver) that manages chain data using labelhashes
 * @dev Source: https://github.com/nxt3d/Wonderland_L2Resolver/blob/dev/src/interfaces/IL2Resolver.sol
 */


          interface IChainRegistry {
              function chainName(bytes calldata _chainIdBytes) external view returns (string memory _chainName);
              function chainId(bytes32 _labelHash) external view returns (bytes memory _chainId);
          }
