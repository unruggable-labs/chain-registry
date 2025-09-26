// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ChainResolver
/// @author @unruggable-labs
/// @notice Extended resolver that stores chain records per label using ENSIP-10 interface.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {HexUtils} from "@ensdomains/ens-contracts/contracts/utils/HexUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {NameCoder} from "@ensdomains/ens-contracts/contracts/utils/NameCoder.sol";
/// @notice Minimal read-only surface expected from a ChainID registry.

interface IChainRegistry {
    function chainName(bytes calldata _chainIdBytes) external view returns (string memory _chainName);

    function chainId(bytes32 labelhash) external view returns (bytes memory _chainId);
}

contract ChainResolver is Ownable, IERC165, IExtendedResolver {
    /// @dev Revert when attempting to register a label that already exists
    error LabelAlreadyRegistered(bytes32 _labelHash);
    // ENS method selectors

    bytes4 public constant ADDR_SELECTOR = bytes4(keccak256("addr(bytes32)"));
    bytes4 public constant ADDR_COINTYPE_SELECTOR = bytes4(keccak256("addr(bytes32,uint256)"));
    bytes4 public constant CONTENTHASH_SELECTOR = bytes4(keccak256("contenthash(bytes32)"));
    bytes4 public constant TEXT_SELECTOR = bytes4(keccak256("text(bytes32,string)"));
    bytes4 public constant DATA_SELECTOR = bytes4(keccak256("data(bytes32,bytes)"));

    // Coin type constants
    uint256 public constant ETHEREUM_COIN_TYPE = 60;

    // Text record key constants
    string public constant CHAIN_ID_TEXT_KEY = "chain-id";

    // Data record key constants
    bytes public constant CHAIN_ID_DATA_KEY = "chain-id";

    // Base node for cid.eth
    bytes32 public constant BASE_NODE = keccak256(abi.encodePacked(bytes32(0), keccak256("cid")));

    // ChainID Registry contract address
    IChainRegistry public chainIDRegistry;

    // Named mappings for better readability
    mapping(bytes32 labelHash => mapping(uint256 coinType => address addr)) private addressRecords;
    mapping(bytes32 labelHash => bytes contentHash) private contenthashRecords;
    mapping(bytes32 labelHash => mapping(string key => string value)) private textRecords;
    mapping(bytes32 labelHash => mapping(bytes key => bytes data)) private dataRecords;

    // Owner and operator mappings
    mapping(bytes32 labelHash => address owner) private labelOwners;
    mapping(address owner => mapping(address operator => bool authorized)) private operators;

    constructor(address _chainIDRegistry) Ownable(msg.sender) {
        chainIDRegistry = IChainRegistry(_chainIDRegistry);
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

        if (selector == ADDR_SELECTOR) {
            // addr(bytes32) - return address for Ethereum (coinType 60)
            address addr = addressRecords[labelHash][ETHEREUM_COIN_TYPE];
            return abi.encode(addr);
        } else if (selector == ADDR_COINTYPE_SELECTOR) {
            // addr(bytes32,uint256) - decode coinType and return address
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            address addr = addressRecords[labelHash][coinType];
            return abi.encode(addr);
        } else if (selector == CONTENTHASH_SELECTOR) {
            // contenthash(bytes32) - return content hash
            bytes memory contentHash = contenthashRecords[labelHash];
            return abi.encode(contentHash);
        } else if (selector == TEXT_SELECTOR) {
            // text(bytes32,string) - decode key and return text value
            (, string memory key) = abi.decode(data[4:], (bytes32, string));

            // Special case for "chain-id" text record
            if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(CHAIN_ID_TEXT_KEY))) {
                // Get chain ID bytes from registry and encode as hex string
                bytes memory chainIdBytes = chainIDRegistry.chainId(labelHash);
                string memory hexString = HexUtils.bytesToHex(chainIdBytes);
                return abi.encode(hexString);
            }

            // Default: return text value from mapping
            string memory value = textRecords[labelHash][key];
            return abi.encode(value);
        } else if (selector == DATA_SELECTOR) {
            // data(bytes32,bytes) - decode key and return data value
            (, bytes memory key) = abi.decode(data[4:], (bytes32, bytes));

            // Special case for "chain-id" data record
            if (keccak256(key) == keccak256(CHAIN_ID_DATA_KEY)) {
                // Return chain ID bytes directly from registry
                return chainIDRegistry.chainId(labelHash);
            }

            // Default: return data value from mapping
            bytes memory dataValue = dataRecords[labelHash][key];
            return abi.encode(dataValue);
        }
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IExtendedResolver).interfaceId;
    }

    /// @notice Set the address for a labelhash with a specific coin type.
    /// @param _labelHash The labelhash to update.
    /// @param _coinType The coin type (default: 60 for Ethereum).
    /// @param _addr The address to set.
    function setAddr(bytes32 _labelHash, uint256 _coinType, address _addr) external onlyOwner {
        addressRecords[_labelHash][_coinType] = _addr;
    }

    /// @notice Set the content hash for a labelhash.
    /// @param _labelHash The labelhash to update.
    /// @param _hash The content hash to set.
    function setContenthash(bytes32 _labelHash, bytes calldata _hash) external onlyOwner {
        contenthashRecords[_labelHash] = _hash;
    }

    /// @notice Set a text record for a labelhash.
    /// @param _labelHash The labelhash to update.
    /// @param _key The text record key.
    /// @param _value The text record value.
    /// @dev Note: "chain-id" text record will be stored but not used - resolve() overrides it with chainIDRegistry value.
    function setText(bytes32 _labelHash, string calldata _key, string calldata _value) external onlyOwner {
        textRecords[_labelHash][_key] = _value;
    }

    /// @notice Set a data record for a labelhash.
    /// @param _labelHash The labelhash to update.
    /// @param _key The data record key.
    /// @param _data The data record value.
    /// @dev Note: "chain-id" data record will be stored but not used - resolve() overrides it with chainIDRegistry value.
    function setData(bytes32 _labelHash, bytes calldata _key, bytes calldata _data) external onlyOwner {
        dataRecords[_labelHash][_key] = _data;
    }

    /// @notice Get the address for a labelhash with a specific coin type.
    /// @param _labelHash The labelhash to query.
    /// @param _coinType The coin type (default: 60 for Ethereum).
    /// @return The address for this label and coin type.
    function getAddr(bytes32 _labelHash, uint256 _coinType) external view returns (address) {
        return addressRecords[_labelHash][_coinType];
    }

    /// @notice Get the content hash for a labelhash.
    /// @param _labelHash The labelhash to query.
    /// @return The content hash for this label.
    function getContenthash(bytes32 _labelHash) external view returns (bytes memory) {
        return contenthashRecords[_labelHash];
    }

    /// @notice Get a text record for a labelhash.
    /// @param _labelHash The labelhash to query.
    /// @param _key The text record key.
    /// @return The text record value.
    function getText(bytes32 _labelHash, string calldata _key) external view returns (string memory) {
        return textRecords[_labelHash][_key];
    }

    /// @notice Get a data record for a labelhash.
    /// @param _labelHash The labelhash to query.
    /// @param _key The data record key.
    /// @return The data record value.
    /// @dev Note: "chain-id" data record will return stored value but resolve() overrides it with chainIDRegistry value.
    function getData(bytes32 _labelHash, bytes calldata _key) external view returns (bytes memory) {
        return dataRecords[_labelHash][_key];
    }

    /// @notice Register a labelhash with an owner.
    /// @param _labelHash The labelhash to register.
    /// @param _owner The owner address for this labelhash.
    function register(bytes32 _labelHash, address _owner) external onlyOwner {
        // Prevent duplicate registrations
        if (labelOwners[_labelHash] != address(0)) {
            revert LabelAlreadyRegistered(_labelHash);
        }
        labelOwners[_labelHash] = _owner;
    }

    /// @notice DEMO: permissionless label registration for showcasing the system
    /// @param _labelHash The labelhash to register
    /// @param _owner The owner address for this labelhash
    function demoRegister(bytes32 _labelHash, address _owner) external {
        if (labelOwners[_labelHash] != address(0)) {
            revert LabelAlreadyRegistered(_labelHash);
        }
        labelOwners[_labelHash] = _owner;
    }

    /// @notice Set an operator for the caller (only owner can call).
    /// @param _operator The operator address to authorize/revoke.
    /// @param _authorized Whether to authorize or revoke the operator.
    function setOperator(address _operator, bool _authorized) external {
        operators[msg.sender][_operator] = _authorized;
    }

    /// @notice Check if an address is an operator for an owner.
    /// @param _owner The owner address to check.
    /// @param _operator The operator address to check.
    /// @return Whether the address is an authorized operator.
    function isOperator(address _owner, address _operator) external view returns (bool) {
        return operators[_owner][_operator];
    }

    /// @notice Get the owner of a labelhash.
    /// @param _labelHash The labelhash to query.
    /// @return The owner address.
    function getOwner(bytes32 _labelHash) external view returns (address) {
        return labelOwners[_labelHash];
    }

    /// @notice Update the chainID registry address.
    /// @param _chainIDRegistry The new chainID registry contract address.
    function updateChainIDRegistry(address _chainIDRegistry) external onlyOwner {
        chainIDRegistry = IChainRegistry(_chainIDRegistry);
    }
}
