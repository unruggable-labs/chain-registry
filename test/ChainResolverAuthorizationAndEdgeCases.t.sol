// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ChainResolver.sol";

contract ChainResolverAuthorizationAndEdgeCasesTest is Test {
    ChainResolver public resolver;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public attacker = address(0x999);
    address public maliciousContract = address(0x666);
    
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
    function test1100_____________________________AUTHORIZATION_AND_EDGE_CASES____________________() public {}
    function test1200________________________________________________________________________________() public {}

    function test_001____register____________________UnauthorizedRegistrationPrevention() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Simulate front-running attack where attacker tries to register same name
        // in a different transaction block
        vm.startPrank(attacker);
        
        // This should fail because attacker is not owner
        vm.expectRevert(); // Should fail due to onlyOwner modifier
        resolver.register(CHAIN_NAME, attacker, CHAIN_ID);
        
        vm.stopPrank();
        
        // Verify original registration is protected
        assertEq(resolver.getOwner(LABEL_HASH), user1, "Original owner should be protected from front-running");
        
        console.log("Successfully prevented unauthorized registration");
    }


    function test_003____setOperator_________________OperatorAuthorization() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets attacker as operator
        vm.startPrank(user1);
        resolver.setOperator(attacker, true);
        
        // Verify attacker is now authorized
        assertTrue(resolver.isAuthorized(LABEL_HASH, attacker), "Attacker should be authorized as operator");
        
        // Attacker tries to escalate privileges by setting themselves as owner
        vm.startPrank(attacker);
        
        // This should work because attacker is authorized as operator
        resolver.setLabelOwner(LABEL_HASH, attacker);
        
        vm.stopPrank();
        
        // Verify ownership was changed by operator (this is actually allowed)
        assertEq(resolver.getOwner(LABEL_HASH), attacker, "Owner should be changeable by authorized operator");
        
        console.log("Successfully handled operator authorization");
    }


    function test_005____resolve_____________________SelectorHandling() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Attacker tries to use malicious selector that might collide
        bytes4 maliciousSelector = 0x00000000; // Zero selector
        
        bytes memory name = abi.encodePacked(bytes1(uint8(bytes(CHAIN_NAME).length)), bytes(CHAIN_NAME), bytes1(0x00));
        bytes memory maliciousData = abi.encodeWithSelector(maliciousSelector, LABEL_HASH);
        
        // This should return empty bytes, not crash
        bytes memory result = resolver.resolve(name, maliciousData);
        bytes memory emptyResult = abi.encode("");
        assertEq(result, emptyResult, "Should return empty bytes for unknown selector");
        
        console.log("Successfully handled selector resolution");
    }

    function test_006____setText_____________________UnauthorizedTextSetting() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets legitimate text record
        vm.startPrank(user1);
        resolver.setText(LABEL_HASH, "description", "Legitimate description");
        
        // Attacker tries to inject malicious content via text record
        // (This should fail due to authorization)
        vm.stopPrank();
        vm.startPrank(attacker);
        
        vm.expectRevert();
        resolver.setText(LABEL_HASH, "description", "<script>alert('hacked')</script>");
        
        vm.stopPrank();
        
        // Verify legitimate content is preserved
        assertEq(resolver.getText(LABEL_HASH, "description"), "Legitimate description", "Legitimate content should be preserved");
        
        console.log("Successfully prevented unauthorized text setting");
    }

    function test_007____setData_____________________LargeDataHandling() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Test with very large data record
        vm.startPrank(user1);
        
        // Create large data (100KB - more reasonable for testing)
        bytes memory largeData = new bytes(1024 * 100);
        for (uint256 i = 0; i < largeData.length; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }
        
        // This should work without overflow
        resolver.setData(LABEL_HASH, "large_data", largeData);
        
        // Verify data was stored correctly
        bytes memory retrievedData = resolver.getData(LABEL_HASH, "large_data");
        assertEq(retrievedData.length, largeData.length, "Large data should be stored correctly");
        
        vm.stopPrank();
        
        console.log("Successfully handled large data");
    }

    function test_008____chainName___________________ReverseLookupEdgeCases() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Attacker tries to manipulate reverse lookup by registering conflicting data
        vm.startPrank(attacker);
        
        // Try to register different chain with same chain ID
        string memory conflictingName = "hacked_optimism";
        bytes32 conflictingLabelHash = keccak256(bytes(conflictingName));
        
        // This should fail because chain ID is already in use
        vm.expectRevert();
        resolver.register(conflictingName, attacker, CHAIN_ID);
        
        vm.stopPrank();
        
        // Verify original reverse lookup is preserved
        assertEq(resolver.chainName(CHAIN_ID), CHAIN_NAME, "Original reverse lookup should be preserved");
        
        console.log("Successfully handled reverse lookup edge cases");
    }

    function test_009____setAddr_____________________AddressEdgeCases() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets legitimate address
        vm.startPrank(user1);
        resolver.setAddr(LABEL_HASH, 60, user1);
        
        // Attacker tries to spoof address (should fail due to authorization)
        vm.stopPrank();
        vm.startPrank(attacker);
        
        vm.expectRevert();
        resolver.setAddr(LABEL_HASH, 60, attacker);
        
        vm.stopPrank();
        
        // Verify legitimate address is preserved
        assertEq(resolver.getAddr(LABEL_HASH, 60), user1, "Legitimate address should be preserved");
        
        console.log("Successfully handled address edge cases");
    }

    function test_010____setContenthash______________ContentHashEdgeCases() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets legitimate content hash
        vm.startPrank(user1);
        bytes memory legitimateHash = hex"e301017012201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
        resolver.setContenthash(LABEL_HASH, legitimateHash);
        
        // Attacker tries to manipulate content hash (should fail due to authorization)
        vm.stopPrank();
        vm.startPrank(attacker);
        
        vm.expectRevert();
        resolver.setContenthash(LABEL_HASH, hex"e30101701220deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef");
        
        vm.stopPrank();
        
        // Verify legitimate content hash is preserved
        assertEq(resolver.getContenthash(LABEL_HASH), legitimateHash, "Legitimate content hash should be preserved");
        
        console.log("Successfully handled content hash edge cases");
    }

    function test_011____isAuthorized_________________AuthorizationLogic() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Test various authorization bypass attempts
        assertFalse(resolver.isAuthorized(LABEL_HASH, attacker), "Attacker should not be authorized");
        assertFalse(resolver.isAuthorized(LABEL_HASH, address(0)), "Zero address should not be authorized");
        assertFalse(resolver.isAuthorized(LABEL_HASH, address(this)), "Contract should not be authorized");
        
        // Verify legitimate authorization works
        assertTrue(resolver.isAuthorized(LABEL_HASH, user1), "Owner should be authorized");
        
        // Set operator and verify
        vm.startPrank(user1);
        resolver.setOperator(user2, true);
        vm.stopPrank();
        
        assertTrue(resolver.isAuthorized(LABEL_HASH, user2), "Operator should be authorized");
        
        console.log("Successfully handled authorization logic");
    }

    function test_012____register____________________GasLimitHandling() public {
        vm.startPrank(admin);
        
        // Test with very long chain name that might cause gas issues
        string memory veryLongName = "this_is_a_very_long_chain_name_that_is_much_longer_than_normal_chain_names_used_in_blockchain_ecosystems_and_should_test_the_limits_of_the_registration_system_and_gas_consumption";
        
        // This should work without hitting gas limits
        resolver.register(veryLongName, user1, CHAIN_ID);
        
        bytes32 longLabelHash = keccak256(bytes(veryLongName));
        assertEq(resolver.getOwner(longLabelHash), user1, "Long name registration should work");
        
        vm.stopPrank();
        
        console.log("Successfully handled gas limit edge cases");
    }
}
