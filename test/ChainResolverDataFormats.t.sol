// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/ChainResolver.sol";

contract ChainResolverDataFormatsTest is Test {
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
    function test1100_____________________________DATA_FORMATS____________________________________() public {}
    function test1200________________________________________________________________________________() public {}

    function test_001____register____________________DuplicateRegistrationHandling() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Attacker tries to find hash collision with legitimate name
        // This is extremely difficult but we test the protection
        string memory collisionAttempt = "optimism";
        
        // Even if they somehow get the same hash, the name is already registered
        bytes32 collisionHash = keccak256(bytes(collisionAttempt));
        
        if (collisionHash == LABEL_HASH) {
            vm.startPrank(attacker);
            vm.expectRevert(); // Should fail due to onlyOwner modifier
            resolver.register(collisionAttempt, attacker, CHAIN_ID);
            vm.stopPrank();
        }
        
        // Verify original registration is protected
        assertEq(resolver.getOwner(LABEL_HASH), user1, "Original owner should be protected from hash collision");
        
        console.log("Successfully handled duplicate registration");
    }

    function test_002____resolve_____________________ComplexDNSEncodingHandling() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Attacker tries complex DNS encoding manipulation
        bytes memory maliciousName = abi.encodePacked(
            bytes1(0x08), // Length byte
            "optimism",
            bytes1(0x00), // Null terminator
            bytes1(0x05), // Additional length byte (malicious)
            "evil",
            bytes1(0x00)
        );
        
        bytes memory textData = abi.encodeWithSelector(resolver.TEXT_SELECTOR(), LABEL_HASH, "chain-id");
        
        // This should still resolve the chain-id correctly despite malicious DNS encoding
        bytes memory result = resolver.resolve(maliciousName, textData);
        bytes memory expectedChainId = abi.encode("000000010001010a00"); // Hex string of CHAIN_ID
        assertEq(result, expectedChainId, "Should resolve chain-id correctly despite malicious DNS encoding");
        
        console.log("Successfully handled complex DNS encoding");
    }


    function test_004____setText_____________________SpecialCharactersAndLongText() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Advanced text injection attempts
        vm.startPrank(user1);
        
        // Test with various special characters and unicode
        string memory specialText = "Test with special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?";
        string memory unicodeText = "Test with unicode: Hello World";
        string memory longText = string(abi.encodePacked(
            "Very long text that might cause issues: ",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ",
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
        ));
        
        // All should work without issues
        resolver.setText(LABEL_HASH, "special", specialText);
        resolver.setText(LABEL_HASH, "unicode", unicodeText);
        resolver.setText(LABEL_HASH, "long", longText);
        
        vm.stopPrank();
        
        // Verify all text was stored correctly
        assertEq(resolver.getText(LABEL_HASH, "special"), specialText, "Special characters should be preserved");
        assertEq(resolver.getText(LABEL_HASH, "unicode"), unicodeText, "Unicode should be preserved");
        assertEq(resolver.getText(LABEL_HASH, "long"), longText, "Long text should be preserved");
        
        console.log("Successfully handled special characters and long text");
    }

    function test_005____setData_____________________VariousDataPatterns() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Sophisticated data manipulation attempts
        vm.startPrank(user1);
        
        // Test with various data patterns
        bytes memory pattern1 = hex"deadbeefcafebabe";
        bytes memory pattern2 = hex"0000000000000000";
        bytes memory pattern3 = hex"ffffffffffffffff";
        bytes memory pattern4 = hex"1234567890abcdef";
        
        // Complex data with nested structures (simulated)
        bytes memory complexData = abi.encode(
            uint256(123456789),
            address(0x1234567890123456789012345678901234567890),
            string("complex data"),
            bytes32(0x1234567890123456789012345678901234567890123456789012345678901234)
        );
        
        // All should work without issues
        resolver.setData(LABEL_HASH, "pattern1", pattern1);
        resolver.setData(LABEL_HASH, "pattern2", pattern2);
        resolver.setData(LABEL_HASH, "pattern3", pattern3);
        resolver.setData(LABEL_HASH, "pattern4", pattern4);
        resolver.setData(LABEL_HASH, "complex", complexData);
        
        vm.stopPrank();
        
        // Verify all data was stored correctly
        assertEq(resolver.getData(LABEL_HASH, "pattern1"), pattern1, "Pattern 1 should be preserved");
        assertEq(resolver.getData(LABEL_HASH, "pattern2"), pattern2, "Pattern 2 should be preserved");
        assertEq(resolver.getData(LABEL_HASH, "pattern3"), pattern3, "Pattern 3 should be preserved");
        assertEq(resolver.getData(LABEL_HASH, "pattern4"), pattern4, "Pattern 4 should be preserved");
        assertEq(resolver.getData(LABEL_HASH, "complex"), complexData, "Complex data should be preserved");
        
        console.log("Successfully handled various data patterns");
    }

    function test_006____setAddr_____________________VariousAddressTypes() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Advanced address spoofing attempts
        vm.startPrank(user1);
        
        // Test with various address types
        address[] memory testAddresses = new address[](5);
        testAddresses[0] = address(0x0); // Zero address
        testAddresses[1] = address(0x1); // Low address
        testAddresses[2] = address(0x1234567890123456789012345678901234567890); // Normal address
        testAddresses[3] = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF); // Max address
        testAddresses[4] = address(this); // Contract address
        
        uint256[] memory coinTypes = new uint256[](5);
        coinTypes[0] = 0;
        coinTypes[1] = 60; // ETH
        coinTypes[2] = 137; // Polygon
        coinTypes[3] = 42161; // Arbitrum
        coinTypes[4] = 999999; // Custom coin type
        
        // Set all addresses
        for (uint256 i = 0; i < testAddresses.length; i++) {
            resolver.setAddr(LABEL_HASH, coinTypes[i], testAddresses[i]);
        }
        
        vm.stopPrank();
        
        // Verify all addresses were set correctly
        for (uint256 i = 0; i < testAddresses.length; i++) {
            assertEq(resolver.getAddr(LABEL_HASH, coinTypes[i]), testAddresses[i], 
                string(abi.encodePacked("Address ", vm.toString(i), " should be preserved")));
        }
        
        console.log("Successfully handled various address types");
    }

    function test_007____setContenthash______________VariousContentHashFormats() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Advanced content hash manipulation attempts
        vm.startPrank(user1);
        
        // Test with various content hash formats
        bytes memory ipfsHash = hex"e301017012201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
        bytes memory swarmHash = hex"e401017012201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
        bytes memory emptyHash = hex"";
        bytes memory invalidHash = hex"deadbeefcafebabe";
        bytes memory veryLongHash = new bytes(1000);
        
        // Fill very long hash with pattern
        for (uint256 i = 0; i < veryLongHash.length; i++) {
            veryLongHash[i] = bytes1(uint8(i % 256));
        }
        
        // All should work without issues
        resolver.setContenthash(LABEL_HASH, ipfsHash);
        assertEq(resolver.getContenthash(LABEL_HASH), ipfsHash, "IPFS hash should be preserved");
        
        resolver.setContenthash(LABEL_HASH, swarmHash);
        assertEq(resolver.getContenthash(LABEL_HASH), swarmHash, "Swarm hash should be preserved");
        
        resolver.setContenthash(LABEL_HASH, emptyHash);
        assertEq(resolver.getContenthash(LABEL_HASH), emptyHash, "Empty hash should be preserved");
        
        resolver.setContenthash(LABEL_HASH, invalidHash);
        assertEq(resolver.getContenthash(LABEL_HASH), invalidHash, "Invalid hash should be preserved");
        
        resolver.setContenthash(LABEL_HASH, veryLongHash);
        assertEq(resolver.getContenthash(LABEL_HASH), veryLongHash, "Very long hash should be preserved");
        
        vm.stopPrank();
        
        console.log("Successfully handled various content hash formats");
    }

    function test_008____resolve_____________________MultiLayerResolution() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Multi-layer attack combining multiple techniques
        vm.startPrank(user1);
        
        // Set up legitimate records
        resolver.setAddr(LABEL_HASH, 60, user1);
        resolver.setText(LABEL_HASH, "description", "Legitimate description");
        resolver.setData(LABEL_HASH, "custom", hex"deadbeef");
        
        vm.stopPrank();
        
        // Attacker tries multiple attack vectors simultaneously
        bytes memory maliciousName = abi.encodePacked(
            bytes1(0x08), // Length
            "optimism",
            bytes1(0x00)  // Null terminator
        );
        
        // Test multiple selectors
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = resolver.ADDR_SELECTOR();
        selectors[1] = resolver.ADDR_COINTYPE_SELECTOR();
        selectors[2] = resolver.TEXT_SELECTOR();
        selectors[3] = resolver.DATA_SELECTOR();
        selectors[4] = resolver.CONTENTHASH_SELECTOR();
        selectors[5] = 0x12345678; // Unknown selector
        
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes memory data;
            if (selectors[i] == resolver.ADDR_SELECTOR()) {
                data = abi.encodeWithSelector(selectors[i], LABEL_HASH);
            } else if (selectors[i] == resolver.ADDR_COINTYPE_SELECTOR()) {
                data = abi.encodeWithSelector(selectors[i], LABEL_HASH, uint256(60));
            } else if (selectors[i] == resolver.TEXT_SELECTOR()) {
                data = abi.encodeWithSelector(selectors[i], LABEL_HASH, "description");
            } else if (selectors[i] == resolver.DATA_SELECTOR()) {
                data = abi.encodeWithSelector(selectors[i], LABEL_HASH, "custom");
            } else if (selectors[i] == resolver.CONTENTHASH_SELECTOR()) {
                data = abi.encodeWithSelector(selectors[i], LABEL_HASH);
            } else {
                data = abi.encodeWithSelector(selectors[i], LABEL_HASH);
            }
            
            bytes memory result = resolver.resolve(maliciousName, data);
            
            // All should return valid results or empty bytes, never crash
            if (selectors[i] == 0x12345678) {
                bytes memory emptyResult = abi.encode("");
                assertEq(result, emptyResult, "Unknown selector should return empty bytes");
            } else {
                assertTrue(result.length > 0, "Known selectors should return valid results");
            }
        }
        
        console.log("Successfully handled multi-layer resolution");
    }

    function test_009____setOperator_________________OperatorManagement() public {
        vm.startPrank(admin);
        
        // Register a chain
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        
        vm.stopPrank();
        
        // Sophisticated operator attack scenarios
        vm.startPrank(user1);
        
        // Set multiple operators
        resolver.setOperator(user2, true);
        resolver.setOperator(attacker, true);
        resolver.setOperator(address(this), true);
        
        // Verify all are authorized
        assertTrue(resolver.isAuthorized(LABEL_HASH, user2), "User2 should be authorized");
        assertTrue(resolver.isAuthorized(LABEL_HASH, attacker), "Attacker should be authorized");
        assertTrue(resolver.isAuthorized(LABEL_HASH, address(this)), "Contract should be authorized");
        
        // Test operator interactions
        vm.stopPrank();
        vm.startPrank(user2);
        
        // User2 tries to remove attacker (this works because setOperator is per-caller)
        resolver.setOperator(attacker, false);
        
        // User2 tries to set new operator (this works because setOperator is per-caller)
        resolver.setOperator(address(0x777), true);
        // But this doesn't make address(0x777) authorized for the label hash
        assertFalse(resolver.isAuthorized(LABEL_HASH, address(0x777)), "New operator should not be authorized for label hash");
        
        vm.stopPrank();
        
        console.log("Successfully handled operator management");
    }

    function test_010____chainName___________________ReverseLookupHandling() public {
        vm.startPrank(admin);
        
        // Register multiple chains with complex relationships
        resolver.register(CHAIN_NAME, user1, CHAIN_ID);
        resolver.register("arbitrum", user2, hex"000000010001016600");
        resolver.register("polygon", user1, hex"000000010001013700");
        
        vm.stopPrank();
        
        // Complex reverse lookup attack scenarios
        // Test with various chain IDs
        bytes[] memory testChainIds = new bytes[](4);
        testChainIds[0] = CHAIN_ID;
        testChainIds[1] = hex"000000010001016600";
        testChainIds[2] = hex"000000010001013700";
        testChainIds[3] = hex"000000010001019999"; // Non-existent
        
        string[] memory expectedNames = new string[](4);
        expectedNames[0] = CHAIN_NAME;
        expectedNames[1] = "arbitrum";
        expectedNames[2] = "polygon";
        expectedNames[3] = "";
        
        for (uint256 i = 0; i < testChainIds.length; i++) {
            string memory result = resolver.chainName(testChainIds[i]);
            assertEq(result, expectedNames[i], 
                string(abi.encodePacked("Chain name ", vm.toString(i), " should match expected")));
        }
        
        console.log("Successfully handled reverse lookup");
    }

    function test_011____supportsInterface___________InterfaceSupport() public {
        // Sophisticated interface manipulation attempts
        
        // Test with various interface IDs
        bytes4[] memory testInterfaces = new bytes4[](10);
        testInterfaces[0] = type(IERC165).interfaceId;
        testInterfaces[1] = type(IExtendedResolver).interfaceId;
        testInterfaces[2] = type(IChainResolver).interfaceId;
        testInterfaces[3] = 0x00000000; // Zero interface
        testInterfaces[4] = 0xffffffff; // Max interface
        testInterfaces[5] = 0x12345678; // Random interface
        testInterfaces[6] = 0xabcdef01; // Another random interface
        testInterfaces[7] = 0x00000001; // Single bit set
        testInterfaces[8] = 0x80000000; // High bit set
        testInterfaces[9] = 0x55555555; // Alternating bits
        
        bool[] memory expectedResults = new bool[](10);
        expectedResults[0] = true;  // IERC165
        expectedResults[1] = true;  // IExtendedResolver
        expectedResults[2] = true;  // IChainResolver
        expectedResults[3] = false; // Zero interface
        expectedResults[4] = false; // Max interface
        expectedResults[5] = false; // Random interface
        expectedResults[6] = false; // Another random interface
        expectedResults[7] = false; // Single bit set
        expectedResults[8] = false; // High bit set
        expectedResults[9] = false; // Alternating bits
        
        for (uint256 i = 0; i < testInterfaces.length; i++) {
            bool result = resolver.supportsInterface(testInterfaces[i]);
            assertEq(result, expectedResults[i], 
                string(abi.encodePacked("Interface ", vm.toString(i), " should return expected result")));
        }
        
        console.log("Successfully handled interface support");
    }

    function test_012____register____________________LargeBatchRegistration() public {
        vm.startPrank(admin);
        
        // Elite registration attack with edge cases
        string[] memory testNames = new string[](5);
        testNames[0] = ""; // Empty name
        testNames[1] = "a"; // Single character
        testNames[2] = "test-chain_123.eth"; // Special characters
        testNames[3] = "VERY_LONG_CHAIN_NAME_THAT_IS_MUCH_LONGER_THAN_NORMAL_CHAIN_NAMES_USED_IN_BLOCKCHAIN_ECOSYSTEMS_AND_SHOULD_TEST_THE_LIMITS_OF_THE_REGISTRATION_SYSTEM_AND_GAS_CONSUMPTION_AND_EDGE_CASES"; // Very long
        testNames[4] = "optimism"; // Normal name
        
        address[] memory testOwners = new address[](5);
        testOwners[0] = address(0x0); // Zero address
        testOwners[1] = address(0x1); // Low address
        testOwners[2] = address(0x1234567890123456789012345678901234567890); // Normal address
        testOwners[3] = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF); // Max address
        testOwners[4] = address(this); // Contract address
        
        bytes[] memory testChainIds = new bytes[](5);
        testChainIds[0] = hex""; // Empty chain ID
        testChainIds[1] = hex"000000010001010a00"; // Normal chain ID
        testChainIds[2] = hex"000000010001016600"; // Another normal chain ID
        testChainIds[3] = new bytes(1000); // Very long chain ID
        testChainIds[4] = hex"000000010001010a00"; // Duplicate chain ID
        
        // Fill very long chain ID
        for (uint256 i = 0; i < testChainIds[3].length; i++) {
            testChainIds[3][i] = bytes1(uint8(i % 256));
        }
        
        // Register all test cases
        for (uint256 i = 0; i < testNames.length; i++) {
            bytes32 labelHash = keccak256(bytes(testNames[i]));
            resolver.register(testNames[i], testOwners[i], testChainIds[i]);
            
            // Verify registration
            assertEq(resolver.getOwner(labelHash), testOwners[i], 
                string(abi.encodePacked("Owner ", vm.toString(i), " should be set correctly")));
            assertEq(resolver.chainId(labelHash), testChainIds[i], 
                string(abi.encodePacked("Chain ID ", vm.toString(i), " should be set correctly")));
        }
        
        vm.stopPrank();
        
        console.log("Successfully handled large batch registration");
    }
}
