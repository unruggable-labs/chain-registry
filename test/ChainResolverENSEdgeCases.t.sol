// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ChainResolver.sol";

contract ChainResolverENSEdgeCasesTest is Test {
    ChainResolver public resolver;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public operator = address(0x4);
    
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
    function test1100_____________________________ENS_EDGE_CASES________________________________() public {}
    function test1200________________________________________________________________________________() public {}

    function test_001____resolve_____________________EmptyNameReturnsEmpty() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Test resolve function with empty name
        bytes memory emptyName = hex"00"; // Just the null terminator
        bytes memory textData = abi.encodeWithSelector(resolver.TEXT_SELECTOR(), LABEL_HASH, "description");
        
        // The resolve function should return empty bytes for invalid DNS encoding
        bytes memory result = resolver.resolve(emptyName, textData);
        bytes memory emptyResult = abi.encode("");
        
        assertEq(result, emptyResult, "Should return empty bytes for invalid DNS encoding");
        
        console.log("Successfully handled empty name in resolve function");
    }

    function test_002____resolve_____________________InvalidDNSEncodingFails() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Test resolve function with invalid DNS encoding (length byte doesn't match actual length)
        bytes memory invalidName = abi.encodePacked(bytes1(0x05), "optimism", bytes1(0x00)); // Length says 5 but actual is 8
        bytes memory textData = abi.encodeWithSelector(resolver.TEXT_SELECTOR(), LABEL_HASH, "description");
        
        // The resolve function should return empty bytes for invalid DNS encoding
        bytes memory result = resolver.resolve(invalidName, textData);
        bytes memory emptyResult = abi.encode("");
        
        assertEq(result, emptyResult, "Should return empty bytes for invalid DNS encoding");
        
        console.log("Successfully handled invalid DNS encoding in resolve function");
    }

    function test_003____resolve_____________________UnknownSelectorReturnsEmpty() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Test resolve function with unknown selector
        bytes memory name = abi.encodePacked(bytes1(uint8(bytes(CHAIN_NAME).length)), bytes(CHAIN_NAME), bytes1(0x00));
        bytes memory unknownData = abi.encodeWithSelector(0x12345678, LABEL_HASH); // Unknown selector
        
        bytes memory result = resolver.resolve(name, unknownData);
        bytes memory emptyResult = abi.encode("");
        
        assertEq(result, emptyResult, "Should return empty bytes for unknown selector");
        
        console.log("Successfully handled unknown selector in resolve function");
    }

    function test_004____setText_____________________EmptyKeyAndValue() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets empty text record
        vm.startPrank(user1);
        
        resolver.setText(LABEL_HASH, "", "");
        
        // Verify empty text record
        assertEq(resolver.getText(LABEL_HASH, ""), "", "Empty text record should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled empty key and value in text record");
    }

    function test_005____setData_____________________EmptyKeyAndData() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets empty data record
        vm.startPrank(user1);
        
        resolver.setData(LABEL_HASH, "", "");
        
        // Verify empty data record
        assertEq(resolver.getData(LABEL_HASH, ""), "", "Empty data record should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled empty key and data in data record");
    }

    function test_006____setAddr_____________________ZeroAddress() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets zero address
        vm.startPrank(user1);
        
        resolver.setAddr(LABEL_HASH, 60, address(0));
        
        // Verify zero address record
        assertEq(resolver.getAddr(LABEL_HASH, 60), address(0), "Zero address record should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled zero address in address record");
    }

    function test_007____setContenthash______________EmptyContentHash() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets empty content hash
        vm.startPrank(user1);
        
        resolver.setContenthash(LABEL_HASH, "");
        
        // Verify empty content hash
        assertEq(resolver.getContenthash(LABEL_HASH), "", "Empty content hash should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled empty content hash");
    }

    function test_008____setText_____________________VeryLongKeyAndValue() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets very long text record
        vm.startPrank(user1);
        
        string memory longKey = "very_long_key_that_is_much_longer_than_normal_keys_used_in_ens_records";
        string memory longValue = "This is a very long value that contains a lot of text and should test the limits of the text record storage system. It includes multiple sentences and various characters to ensure proper handling of longer text records in the ENS system.";
        
        resolver.setText(LABEL_HASH, longKey, longValue);
        
        // Verify long text record
        assertEq(resolver.getText(LABEL_HASH, longKey), longValue, "Long text record should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled very long key and value in text record");
    }

    function test_009____setData_____________________LargeDataRecord() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets large data record
        vm.startPrank(user1);
        
        bytes memory key = "large_data";
        bytes memory largeData = new bytes(1000); // 1KB of data
        for (uint256 i = 0; i < largeData.length; i++) {
            largeData[i] = bytes1(uint8(i % 256));
        }
        
        resolver.setData(LABEL_HASH, key, largeData);
        
        // Verify large data record
        assertEq(resolver.getData(LABEL_HASH, key), largeData, "Large data record should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled large data record");
    }

    function test_010____resolve_____________________NonExistentLabelHash() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Test resolve function with non-existent label hash
        bytes memory name = abi.encodePacked(bytes1(uint8(bytes(CHAIN_NAME).length)), bytes(CHAIN_NAME), bytes1(0x00));
        bytes32 nonExistentLabelHash = keccak256("nonexistent");
        bytes memory textData = abi.encodeWithSelector(resolver.TEXT_SELECTOR(), nonExistentLabelHash, "description");
        
        bytes memory result = resolver.resolve(name, textData);
        string memory resolvedText = abi.decode(result, (string));
        
        assertEq(resolvedText, "", "Should return empty string for non-existent label hash");
        
        console.log("Successfully handled non-existent label hash in resolve function");
    }

    function test_011____setRecord___________________OverwriteExistingRecord() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets initial text record
        vm.startPrank(user1);
        resolver.setText(LABEL_HASH, "description", "Initial description");
        assertEq(resolver.getText(LABEL_HASH, "description"), "Initial description", "Initial record should be set");
        
        // Overwrite with new value
        resolver.setText(LABEL_HASH, "description", "Updated description");
        assertEq(resolver.getText(LABEL_HASH, "description"), "Updated description", "Record should be overwritten");
        
        vm.stopPrank();
        
        console.log("Successfully handled overwriting existing record");
    }

    function test_012____setAddr_____________________MultipleCoinTypes() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // User1 sets multiple coin type addresses
        vm.startPrank(user1);
        
        address ethAddr = address(0x123);
        address btcAddr = address(0x456);
        address solAddr = address(0x789);
        
        resolver.setAddr(LABEL_HASH, 60, ethAddr);   // Ethereum
        resolver.setAddr(LABEL_HASH, 0, btcAddr);    // Bitcoin
        resolver.setAddr(LABEL_HASH, 501, solAddr);  // Solana
        
        // Verify all addresses
        assertEq(resolver.getAddr(LABEL_HASH, 60), ethAddr, "Ethereum address should be set");
        assertEq(resolver.getAddr(LABEL_HASH, 0), btcAddr, "Bitcoin address should be set");
        assertEq(resolver.getAddr(LABEL_HASH, 501), solAddr, "Solana address should be set");
        
        vm.stopPrank();
        
        console.log("Successfully handled multiple coin types");
    }
}
