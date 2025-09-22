// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ChainResolver
/// @author @unruggable-labs
/// @notice Minimal resolver that stores a single canonical chain-id record per node.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IENSIPTBD9 {
    event AddressChanged(bytes32 indexed node, uint256 key, bytes data);

    function addr(bytes32 node, uint256 key) external view returns (bytes memory);
}

contract ChainResolver is Ownable, IERC165, IENSIPTBD9 {
    error InvalidKey();

    // keyGen("chain-id") = (uint256(keccak256("chain-id")) - 1) << 32
    uint256 public constant CHAIN_ID_KEY = 0xa8c8594bfda2da5d8830d2367f8d6c34e565e2cf5616ba1ede2c620d00000000;

    mapping(bytes32 => bytes) private chainIdRecords;
    mapping(bytes32 => bytes32) private reverseMapping;

    constructor() Ownable(msg.sender) {}

    /// @notice Resolve the canonical chain-id bytes stored for a node.
    /// @param _node The ENS node being queried.
    /// @param _key The key being resolved.
    function addr(bytes32 _node, uint256 _key) external view override returns (bytes memory) {
        if (_key != CHAIN_ID_KEY) return bytes("");
        return chainIdRecords[_node];
    }

    /// @notice Store chain-id bytes for a node.
    /// @param _node The ENS node to update.
    /// @param _key The key that must equal CHAIN_ID_KEY.
    /// @param _data Arbitrary bytes.
    function setAddr(bytes32 _node, uint256 _key, bytes calldata _data) external onlyOwner {
        if (_key != CHAIN_ID_KEY) revert InvalidKey();
        bytes memory current = chainIdRecords[_node];
        if (current.length != 0) {
            delete reverseMapping[keccak256(current)];
        }

        chainIdRecords[_node] = _data;
        if (_data.length != 0) {
            reverseMapping[keccak256(_data)] = _node;
        }
        emit AddressChanged(_node, _key, _data);
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IENSIPTBD9).interfaceId;
    }

    /// @notice Reverse map bytes back to the node.
    /// @param _data The chain-id bytes that were stored.
    /// @return node_ The ENS node that owns the payload.
    function node(bytes calldata _data) external view returns (bytes32) {
        return reverseMapping[keccak256(_data)];
    }
}
