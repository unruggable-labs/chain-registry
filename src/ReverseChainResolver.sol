// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ReverseChainResolver
/// @author @unruggable-labs
/// @notice Extended resolver that resolves chain names from chain IDs using ENSIP-10 interface.

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IExtendedResolver} from "./interfaces/IExtendedResolver.sol";
import {NameCoder} from "./utils/NameCoder.sol";
import {HexUtils} from "./utils/HexUtils.sol";
import {IChainRegistry} from "./interfaces/IChainRegistry.sol";

contract ReverseChainResolver is IERC165, IExtendedResolver {
    // ENS method selectors
    bytes4 public constant TEXT_SELECTOR = bytes4(keccak256("text(bytes32,string)"));
    bytes4 public constant DATA_SELECTOR = bytes4(keccak256("data(bytes32,bytes)"));

    // Text record key prefix
    string public constant CHAIN_NAME_TEXT_PREFIX = "chain-name:";

    // Data record key prefix
    string public constant CHAIN_NAME_DATA_PREFIX = "chain-name:";

    // Base node for cid.eth
    bytes32 public constant BASE_NODE = keccak256(abi.encodePacked(bytes32(0), keccak256("cid")));

    // ChainID Registry contract address
    IChainRegistry public chainRegistry;

    constructor(address _chainRegistry) {
        chainRegistry = IChainRegistry(_chainRegistry);
    }

    /// @notice Resolve data for a DNS-encoded name using ENSIP-10 interface.
    /// @param name The DNS-encoded name.
    /// @param data The ABI-encoded ENS method call data.
    /// @return The resolved data based on the method selector.
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {
        // Extract the first label from the DNS-encoded name
        (bytes32 labelHash,,,) = NameCoder.readLabel(name, 0, true);

        // Get the method selector (first 4 bytes)
        bytes4 selector = bytes4(data);

        if (selector == TEXT_SELECTOR) {
            // text(bytes32,string) - decode key and return text value
            (, string memory key) = abi.decode(data[4:], (bytes32, string));

            // Check if key starts with "chain-name:" prefix
            bytes memory keyBytes = bytes(key);
            bytes memory prefixBytes = bytes(CHAIN_NAME_TEXT_PREFIX);
            if (_startsWith(keyBytes, prefixBytes)) {
                // Extract chainId from key (remove "chain-name:" prefix)
                string memory chainIdHex = _substring(key, prefixBytes.length, keyBytes.length);
                bytes memory chainIdBytes = bytes(chainIdHex);
                string memory chainName = chainRegistry.chainName(chainIdBytes);
                return abi.encode(chainName);
            }

            // Return empty bytes for non-chain-name keys
            return abi.encode("");
        } else if (selector == DATA_SELECTOR) {
            // data(bytes32,bytes) - decode key and return data value
            (, bytes memory key) = abi.decode(data[4:], (bytes32, bytes));

            // Check if key starts with "chain-name:" prefix
            bytes memory prefixBytes = abi.encode(CHAIN_NAME_DATA_PREFIX);
            if (_startsWith(key, prefixBytes)) {
                // Extract chainId from key (remove "chain-name:" prefix)
                bytes memory chainIdBytes = new bytes(key.length - prefixBytes.length);
                for (uint256 i = 0; i < chainIdBytes.length; i++) {
                    chainIdBytes[i] = key[prefixBytes.length + i];
                }
                string memory chainName = chainRegistry.chainName(chainIdBytes);
                return abi.encode(chainName);
            }

            // Return empty bytes for non-chain-name keys
            return abi.encode(bytes(""));
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IExtendedResolver).interfaceId;
    }

    /// @notice Check if bytes starts with a prefix
    /// @param data The bytes to check
    /// @param prefix The prefix to look for
    /// @return True if data starts with prefix
    function _startsWith(bytes memory data, bytes memory prefix) internal pure returns (bool) {
        if (data.length < prefix.length) return false;
        for (uint256 i = 0; i < prefix.length; i++) {
            if (data[i] != prefix[i]) return false;
        }
        return true;
    }

    /// @notice Extract substring from string
    /// @param str The string to extract from
    /// @param start The start index
    /// @param end The end index
    /// @return The extracted substring
    function _substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }
}
