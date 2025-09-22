// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ChainResolver, IENSIPTBD9} from "../src/ChainResolver.sol";

contract ChainResolverTest is Test {
    ChainResolver internal resolver;
    uint256 internal canonicalKey;

    bytes32 internal constant NODE = bytes32(uint256(keccak256(abi.encodePacked("base.cid.eth"))));
    bytes internal constant DEFAULT_ADDR_PAYLOAD = hex"deadbeef";
    address internal constant ATTACKER = address(0xBEEF);

    function setUp() external {
        resolver = new ChainResolver();
        canonicalKey = resolver.CHAIN_ID_KEY();
    }

    function testSetAddrStoresBytes() external {
        vm.expectEmit(true, true, true, true, address(resolver));
        emit IENSIPTBD9.AddressChanged(NODE, canonicalKey, DEFAULT_ADDR_PAYLOAD);

        resolver.setAddr(NODE, canonicalKey, DEFAULT_ADDR_PAYLOAD);

        bytes memory stored = resolver.addr(NODE, canonicalKey);
        assertEq(stored, DEFAULT_ADDR_PAYLOAD, "stored bytes mismatch");
    }

    function testIReturnsNode() external {
        resolver.setAddr(NODE, canonicalKey, DEFAULT_ADDR_PAYLOAD);

        bytes32 resolvedNode = resolver.node(DEFAULT_ADDR_PAYLOAD);
        assertEq(resolvedNode, NODE, "reverse lookup returned wrong node");
    }

    function testSetAddrRevertsForInvalidKey() external {
        uint256 badKey = canonicalKey + 1;

        vm.expectRevert(abi.encodeWithSelector(ChainResolver.InvalidKey.selector));
        resolver.setAddr(NODE, badKey, DEFAULT_ADDR_PAYLOAD);
    }

    function testNodeUpdatesAfterChange() external {
        bytes memory first = DEFAULT_ADDR_PAYLOAD;
        bytes memory second = hex"cafebabe";

        resolver.setAddr(NODE, canonicalKey, first);
        resolver.setAddr(NODE, canonicalKey, second);

        assertEq(resolver.node(first), bytes32(0), "old payload should be cleared");
        assertEq(resolver.node(second), NODE, "new payload not indexed");
    }

    function testSetAddrRevertsForNonOwner() external {
        vm.startPrank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        resolver.setAddr(NODE, canonicalKey, DEFAULT_ADDR_PAYLOAD);
        vm.stopPrank();
    }

    function testAddrReturnsEmptyForUnknownKey() external view {
        uint256 wrongKey = canonicalKey + 1;
        bytes memory resolved = resolver.addr(NODE, wrongKey);
        assertEq(resolved.length, 0, "unexpected bytes returned for unknown key");
    }
}
