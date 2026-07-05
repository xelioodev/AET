// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AethiItems} from "../../src/items/AethiItems.sol";

contract AethiItemsTest is Test {
    uint256 internal signerKey = 0xA11CE;
    address internal admin = vm.addr(signerKey);
    address internal alice = address(0xA1);

    AethiItems internal items;

    function setUp() public {
        items = new AethiItems(admin);
    }

    function testMintWithSignatureMintsItemAndConsumesNonce() public {
        bytes memory signature = _signMint(alice, 1, 1_500, "ipfs://sword.json", 0, block.timestamp + 1 days);

        uint256 tokenId =
            items.mintWithSignature(alice, 1, 1_500, "ipfs://sword.json", 0, block.timestamp + 1 days, signature);

        assertEq(tokenId, 1);
        assertEq(items.ownerOf(tokenId), alice);
        assertEq(items.itemPower(tokenId), 1_500);
        assertEq(items.tokenURI(tokenId), "ipfs://sword.json");
        assertEq(items.nonces(alice), 1);
    }

    function testRejectsReplay() public {
        bytes memory signature = _signMint(alice, 1, 500, "ipfs://shield.json", 0, block.timestamp + 1 days);

        items.mintWithSignature(alice, 1, 500, "ipfs://shield.json", 0, block.timestamp + 1 days, signature);

        vm.expectRevert();
        items.mintWithSignature(alice, 1, 500, "ipfs://shield.json", 0, block.timestamp + 1 days, signature);
    }

    function testRejectsExpiredAuthorization() public {
        bytes memory signature = _signMint(alice, 1, 500, "ipfs://expired.json", 0, block.timestamp);

        vm.warp(block.timestamp + 1);

        vm.expectRevert(AethiItems.AuthorizationExpired.selector);
        items.mintWithSignature(alice, 1, 500, "ipfs://expired.json", 0, block.timestamp - 1, signature);
    }

    function _signMint(
        address player,
        uint256 itemType,
        uint256 powerBps,
        string memory tokenUri,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 digest = items.hashMintAuthorization(player, itemType, powerBps, tokenUri, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
