// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IChainRegistry} from "src/interfaces/IChainRegistry.sol";

/**
 * @title ChainRegistry
 * @author @defi-wonderland, @unruggable-labs
 * @notice Minimal L2 Resolver system. It resolves labelhashes to their corresponding
 * formatted chain identifiers and allows reverse lookup by mapping them back to their chain names.
 * Uses labelhashes (keccak256 of labels like "optimism") instead of full namehashes for simplicity.
 * EIP-7930 is an example of supported chain identifier.
 * Source: https://github.com/nxt3d/Wonderland_L2Resolver/blob/dev/src/contracts/L2Resolver.sol
 */
contract ChainRegistry is IChainRegistry, IERC165, Ownable {
    /// @dev Revert when attempting to register a label that already exists
    error LabelAlreadyRegistered(bytes32 _labelHash);

    /// @notice Forward lookup: labelhash => chain data

    mapping(bytes32 _labelHash => ChainData _chainData) internal chainData;

    /// @notice Reverse lookup: chain ID => labelhash
    mapping(bytes _chainId => bytes32 _labelHash) internal reverseLookup;

    /// @notice Labelhash => owner mapping
    mapping(bytes32 _labelHash => address _owner) internal labelOwners;

    /// @notice Owner => operator => bool mapping
    mapping(address _owner => mapping(address _operator => bool _isOperator)) internal operators;

    /**
     * @notice Constructor
     * @param _owner The address to set as the owner
     */
    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc IChainRegistry
    function setRecord(bytes32 _labelHash, bytes calldata _chainId, string calldata _chainName) external {
        _authenticateCaller(msg.sender, _labelHash);
        chainData[_labelHash] = ChainData(_chainId, _chainName);
        reverseLookup[_chainId] = _labelHash;
        emit RecordSet(_labelHash, _chainId, _chainName);
    }

    /// @inheritdoc IChainRegistry
    function setRecords(bytes32[] calldata _labelHashes, bytes[] calldata _chainIds, string[] calldata _chainNames)
        external
    {
        uint256 _length = _labelHashes.length;
        if (_length != _chainIds.length || _length != _chainNames.length) {
            revert InvalidDataLength();
        }

        for (uint256 i = 0; i < _length; i++) {
            _authenticateCaller(msg.sender, _labelHashes[i]);
            chainData[_labelHashes[i]] = ChainData(_chainIds[i], _chainNames[i]);
            reverseLookup[_chainIds[i]] = _labelHashes[i];
            emit RecordSet(_labelHashes[i], _chainIds[i], _chainNames[i]);
        }
    }

    /// @inheritdoc IChainRegistry
    function chainName(bytes calldata _chainIdBytes) external view returns (string memory _chainName) {
        bytes32 _labelHash = reverseLookup[_chainIdBytes];
        _chainName = chainData[_labelHash].chainName;
    }

    /// @inheritdoc IChainRegistry
    function chainId(bytes32 _labelHash) external view returns (bytes memory _chainId) {
        _chainId = chainData[_labelHash].chainId;
    }

    /// @inheritdoc IChainRegistry
    function register(string calldata _chainName, address _owner, bytes calldata _chainId) external onlyOwner {
        bytes32 _labelHash = keccak256(bytes(_chainName));

        // Prevent overwriting an existing label registration
        if (labelOwners[_labelHash] != address(0)) {
            revert LabelAlreadyRegistered(_labelHash);
        }

        // Set the owner
        labelOwners[_labelHash] = _owner;

        // Set the chain data and reverse lookup
        chainData[_labelHash] = ChainData(_chainId, _chainName);
        reverseLookup[_chainId] = _labelHash;

        emit LabelOwnerSet(_labelHash, _owner);
        emit RecordSet(_labelHash, _chainId, _chainName);
    }

    /**
     * @notice DEMO: permissionless register for showcasing the system
     * @dev Same behavior as register() but without onlyOwner; prevents duplicate labels
     */
    function demoRegister(string calldata _chainName, address _owner, bytes calldata _chainId) external {
        bytes32 _labelHash = keccak256(bytes(_chainName));

        if (labelOwners[_labelHash] != address(0)) {
            revert LabelAlreadyRegistered(_labelHash);
        }

        labelOwners[_labelHash] = _owner;
        chainData[_labelHash] = ChainData(_chainId, _chainName);
        reverseLookup[_chainId] = _labelHash;

        emit LabelOwnerSet(_labelHash, _owner);
        emit RecordSet(_labelHash, _chainId, _chainName);
    }

    /// @inheritdoc IChainRegistry
    function setLabelOwner(bytes32 _labelHash, address _owner) external {
        // Only the current owner can transfer ownership
        if (labelOwners[_labelHash] != address(0) && labelOwners[_labelHash] != msg.sender) {
            revert NotAuthorized(msg.sender, _labelHash);
        }
        labelOwners[_labelHash] = _owner;
        emit LabelOwnerSet(_labelHash, _owner);
    }

    /// @inheritdoc IChainRegistry
    function setOperator(address _operator, bool _isOperator) external {
        operators[msg.sender][_operator] = _isOperator;
        emit OperatorSet(msg.sender, _operator, _isOperator);
    }

    /// @inheritdoc IChainRegistry
    function isAuthorized(bytes32 _labelHash, address _address) external view returns (bool _authorized) {
        address _owner = labelOwners[_labelHash];
        return _owner == _address || operators[_owner][_address];
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool _isSupported) {
        _isSupported = (_interfaceId == type(IERC165).interfaceId);
    }

    /**
     * @notice Authenticates the caller for a given labelhash.
     * @param _caller The address to check.
     * @param _labelHash The labelhash to check.
     */
    function _authenticateCaller(address _caller, bytes32 _labelHash) internal view {
        address _owner = labelOwners[_labelHash];
        if (_owner != _caller && !operators[_owner][_caller]) {
            revert NotAuthorized(_caller, _labelHash);
        }
    }
}
