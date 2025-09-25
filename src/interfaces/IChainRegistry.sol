// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IChainRegistry
 * @author @defi-wonderland
 * @notice Interface for the ChainRegistry (formerly L2Resolver) that manages chain data using labelhashes
 * @dev Source: https://github.com/nxt3d/Wonderland_L2Resolver/blob/dev/src/interfaces/IL2Resolver.sol
 */
interface IChainRegistry {
  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Chain data structure containing chain ID and name
   */
  struct ChainData {
    bytes chainId;
    string chainName;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a record is set (both forward and reverse lookup)
   * @param _labelHash The labelhash to store the data for
   * @param _chainId The chain ID bytes
   * @param _chainName The human-readable chain name
   */
  event RecordSet(bytes32 indexed _labelHash, bytes _chainId, string _chainName);

  /**
   * @notice Emitted when a labelhash owner is set
   * @param _labelHash The labelhash to set the owner for
   * @param _owner The address set as the owner
   */
  event LabelOwnerSet(bytes32 indexed _labelHash, address _owner);

  /**
   * @notice Emitted when an operator is set
   * @param _owner The owner setting the operator
   * @param _operator The address set as an operator
   * @param _isOperator True if granted operator status, false if revoked
   */
  event OperatorSet(address indexed _owner, address indexed _operator, bool _isOperator);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not authorized to set a value for a labelhash
   * @param _caller The address that attempted to set the value
   * @param _labelHash The labelhash that the value was attempted to be set for
   */
  error NotAuthorized(address _caller, bytes32 _labelHash);

  /**
   * @notice Thrown when the input data length is invalid
   */
  error InvalidDataLength();

  /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sets both forward and reverse lookup records for a labelhash
   * @param _labelHash The labelhash to set the chain data for
   * @param _chainId The chain ID bytes to associate with the labelhash
   * @param _chainName The human-readable chain name to associate with the chain ID
   */
  function setRecord(bytes32 _labelHash, bytes calldata _chainId, string calldata _chainName) external;

  /**
   * @notice Sets multiple records in batch
   * @param _labelHashes The labelhashes to set chain data for
   * @param _chainIds The chain ID bytes to associate with each labelhash
   * @param _chainNames The human-readable chain names to associate with each chain ID
   */
  function setRecords(bytes32[] calldata _labelHashes, bytes[] calldata _chainIds, string[] calldata _chainNames) external;

  /**
   * @notice Retrieves the chain name for a given chain ID
   * @param _chainIdBytes The chain ID bytes to look up
   * @return _chainName The human-readable chain name
   */
  function chainName(bytes calldata _chainIdBytes) external view returns (string memory _chainName);

  /**
   * @notice Retrieves the chain ID for a given labelhash
   * @param _labelHash The labelhash to look up
   * @return _chainId The chain ID bytes
   */
  function chainId(bytes32 _labelHash) external view returns (bytes memory _chainId);

  /**
   * @notice Owner function to register a chain
   * @param _chainName The chain name (e.g., "optimism")
   * @param _owner The address to set as the owner of the labelhash
   * @param _chainId The chain ID bytes to associate with the labelhash
   */
  function register(string calldata _chainName, address _owner, bytes calldata _chainId) external;

  /**
   * @notice Sets the owner of a labelhash
   * @param _labelHash The labelhash to set the owner for
   * @param _owner The address to set as the owner
   */
  function setLabelOwner(bytes32 _labelHash, address _owner) external;

  /**
   * @notice Sets an operator for the caller
   * @param _operator The address to set as an operator
   * @param _isOperator True to grant operator status, false to revoke
   */
  function setOperator(address _operator, bool _isOperator) external;

  /**
   * @notice Checks if an address is authorized for a labelhash (owner or operator)
   * @param _labelHash The labelhash to check
   * @param _address The address to check
   * @return _authorized True if the address is authorized
   */
  function isAuthorized(bytes32 _labelHash, address _address) external view returns (bool _authorized);

}

