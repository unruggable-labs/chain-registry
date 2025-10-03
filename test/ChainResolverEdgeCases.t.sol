// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ChainResolver.sol";

contract ChainResolverEdgeCasesTest is Test {
    ChainResolver public resolver;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public operator = address(0x4);
    address public zeroAddress = address(0x0);
    
    // Test data - using 7930 chain ID format
    string public constant CHAIN_NAME = "optimism";
    bytes public constant CHAIN_ID = hex"000000010001010a00";
    bytes32 public constant LABEL_HASH = keccak256(bytes(CHAIN_NAME));

    function setUp() public {
        vm.startPrank(admin);
        resolver = new ChainResolver(admin);
        vm.stopPrank();
    }

    // Identify the file being tested
    function test1000________________________________________________________________________________() public {}
    function test1100_____________________________CHAINRESOLVER_EDGE_CASES________________________() public {}
    function test1200________________________________________________________________________________() public {}

    function test_001____register____________________EmptyChainName() public {
        vm.startPrank(admin);
        
        // Try to register with empty chain name
        string memory emptyName = "";
        bytes32 emptyLabelHash = keccak256(bytes(emptyName));
        
        // This should work - empty string is valid
        resolver.register(emptyName, user1, CHAIN_ID);
        
        // Verify registration
        assertEq(resolver.getOwner(emptyLabelHash), user1, "Empty chain name should be registrable");
        assertEq(resolver.chainId(emptyLabelHash), CHAIN_ID, "Chain ID should be set for empty name");
        
        vm.stopPrank();
        
        console.log("Successfully registered empty chain name");
    }

    function test_002____register____________________VeryLongChainName() public {
        vm.startPrank(admin);
        
        // Try to register with very long chain name
        string memory longName = "this_is_a_very_long_chain_name_that_is_much_longer_than_normal_chain_names_used_in_blockchain_ecosystems_and_should_test_the_limits_of_the_registration_system";
        bytes32 longLabelHash = keccak256(bytes(longName));
        
        // This should work - long names are valid
        resolver.register(longName, user1, CHAIN_ID);
        
        // Verify registration
        assertEq(resolver.getOwner(longLabelHash), user1, "Long chain name should be registrable");
        assertEq(resolver.chainId(longLabelHash), CHAIN_ID, "Chain ID should be set for long name");
        
        vm.stopPrank();
        
        console.log("Successfully registered very long chain name");
    }

    function test_003____register____________________ZeroAddressOwner() public {
        vm.startPrank(admin);
        
        // Try to register with zero address as owner
        resolver.register(CHAIN_NAME, zeroAddress, CHAIN_ID);
        
        // Verify registration
        assertEq(resolver.getOwner(LABEL_HASH), zeroAddress, "Zero address should be valid owner");
        assertEq(resolver.chainId(LABEL_HASH), CHAIN_ID, "Chain ID should be set");
        
        vm.stopPrank();
        
        console.log("Successfully registered with zero address owner");
    }

    function test_004____register____________________EmptyChainId() public {
        vm.startPrank(admin);
        
        // Try to register with empty chain ID
        bytes memory emptyChainId = "";
        
        resolver.register(CHAIN_NAME, user1, emptyChainId);
        
        // Verify registration
        assertEq(resolver.getOwner(LABEL_HASH), user1, "Owner should be set");
        assertEq(resolver.chainId(LABEL_HASH), emptyChainId, "Empty chain ID should be stored");
        assertEq(resolver.chainName(emptyChainId), CHAIN_NAME, "Chain name should be stored");
        
        vm.stopPrank();
        
        console.log("Successfully registered with empty chain ID");
    }

    function test_005____register____________________VeryLongChainId() public {
        vm.startPrank(admin);
        
        // Try to register with very long chain ID
        bytes memory longChainId = new bytes(1000);
        for (uint256 i = 0; i < longChainId.length; i++) {
            longChainId[i] = bytes1(uint8(i % 256));
        }
        
        resolver.register(CHAIN_NAME, user1, longChainId);
        
        // Verify registration
        assertEq(resolver.getOwner(LABEL_HASH), user1, "Owner should be set");
        assertEq(resolver.chainId(LABEL_HASH), longChainId, "Long chain ID should be stored");
        assertEq(resolver.chainName(longChainId), CHAIN_NAME, "Chain name should be stored");
        
        vm.stopPrank();
        
        console.log("Successfully registered with very long chain ID");
    }

    function test_006____register____________________DuplicateRegistrationOverwrites() public {
        vm.startPrank(admin);
        
        // Register first time
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        // Try to register again with different owner - should succeed (overwrites)
        resolver.register(CHAIN_NAME, user2, CHAIN_ID);
        
        // Verify second registration overwrote the first
        assertEq(resolver.getOwner(LABEL_HASH), user2, "Second owner should overwrite first");
        
        vm.stopPrank();
        
        console.log("Successfully allowed duplicate registration (overwrite)");
    }



    function test_009____setOperator_________________SelfAsOperator() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets themselves as operator
        vm.startPrank(user1);
        resolver.setOperator(user1, true);
        
        // Verify they are authorized (they should be anyway as owner)
        assertTrue(resolver.isAuthorized(LABEL_HASH, user1), "User should be authorized as owner");
        
        vm.stopPrank();
        
        console.log("Successfully set self as operator");
    }

    function test_010____setOperator_________________ZeroAddressOperator() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets zero address as operator
        vm.startPrank(user1);
        resolver.setOperator(zeroAddress, true);
        
        // Verify zero address is authorized
        assertTrue(resolver.isAuthorized(LABEL_HASH, zeroAddress), "Zero address should be authorized as operator");
        
        vm.stopPrank();
        
        console.log("Successfully set zero address as operator");
    }

    function test_011____setLabelOwner_______________TransferToZeroAddress() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 transfers ownership to zero address
        vm.startPrank(user1);
        resolver.setLabelOwner(LABEL_HASH, zeroAddress);
        
        // Verify transfer
        assertEq(resolver.getOwner(LABEL_HASH), zeroAddress, "Zero address should be valid owner");
        
        vm.stopPrank();
        
        console.log("Successfully transferred ownership to zero address");
    }

    function test_012____setLabelOwner_______________TransferToSelf() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 transfers ownership to themselves
        vm.startPrank(user1);
        resolver.setLabelOwner(LABEL_HASH, user1);
        
        // Verify transfer (should still be user1)
        assertEq(resolver.getOwner(LABEL_HASH), user1, "User should still own after self-transfer");
        
        vm.stopPrank();
        
        console.log("Successfully transferred ownership to self");
    }



    function test_015____chainName___________________UnknownChainId() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Try to get chain name for unknown chain ID
        bytes memory unknownChainId = hex"000000010001019900"; // Different chain ID
        string memory result = resolver.chainName(unknownChainId);
        
        // Should return empty string
        assertEq(result, "", "Should return empty string for unknown chain ID");
        
        console.log("Successfully returned empty string for unknown chain ID");
    }

    function test_016____chainId_____________________UnknownLabelHash() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Try to get chain ID for unknown label hash
        bytes32 unknownLabelHash = keccak256("unknown");
        bytes memory result = resolver.chainId(unknownLabelHash);
        
        // Should return empty bytes
        assertEq(result, "", "Should return empty bytes for unknown label hash");
        
        console.log("Successfully returned empty bytes for unknown label hash");
    }

    function test_017____isAuthorized_________________NonExistentLabelHash() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Check authorization for non-existent label hash
        bytes32 nonExistentLabelHash = keccak256("nonexistent");
        bool result = resolver.isAuthorized(nonExistentLabelHash, user1);
        
        // Should return false
        assertFalse(result, "Should return false for non-existent label hash");
        
        console.log("Successfully returned false for non-existent label hash");
    }

    function test_018____setOperator_________________RemoveOperator() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets operator
        vm.startPrank(user1);
        resolver.setOperator(operator, true);
        assertTrue(resolver.isAuthorized(LABEL_HASH, operator), "Operator should be authorized");
        
        // Remove operator
        resolver.setOperator(operator, false);
        assertFalse(resolver.isAuthorized(LABEL_HASH, operator), "Operator should no longer be authorized");
        
        vm.stopPrank();
        
        console.log("Successfully removed operator");
    }

    function test_019____register____________________SpecialCharactersInName() public {
        vm.startPrank(admin);
        
        // Try to register with special characters
        string memory specialName = "test-chain_123.eth";
        bytes32 specialLabelHash = keccak256(bytes(specialName));
        
        resolver.register(specialName, user1, CHAIN_ID);
        
        // Verify registration
        assertEq(resolver.getOwner(specialLabelHash), user1, "Special character name should be registrable");
        assertEq(resolver.chainId(specialLabelHash), CHAIN_ID, "Chain ID should be set");
        
        vm.stopPrank();
        
        console.log("Successfully registered name with special characters");
    }

}
