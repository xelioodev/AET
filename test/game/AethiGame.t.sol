// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AethiGame} from "../../src/game/AethiGame.sol";
import {AethiItems} from "../../src/items/AethiItems.sol";
import {AethiStaking} from "../../src/staking/AethiStaking.sol";
import {AethiToken} from "../../src/token/AethiToken.sol";

contract AethiGameTest is Test {
    uint256 internal adminKey = 0xA11CE;
    address internal admin = vm.addr(adminKey);

    AethiToken internal token;
    AethiItems internal items;
    AethiStaking internal staking;
    AethiGame internal game;

    address internal treasury = address(0xBEEF);
    address internal alice = address(0xA1);

    function setUp() public {
        token = new AethiToken(admin, admin, 20_000 ether, 100_000 ether);
        items = new AethiItems(admin);
        staking = new AethiStaking(token, token, admin, 30 days);
        game = new AethiGame(token, staking, treasury, admin, 100 ether, 1 ether);
        vm.prank(admin);
        game.setItemCollection(items);

        vm.prank(admin);
        assertTrue(token.transfer(alice, 1_000 ether));

        vm.startPrank(alice);
        token.approve(address(staking), 200 ether);
        staking.stake(200 ether);
        token.approve(address(game), 10 ether);
        vm.stopPrank();
    }

    function testSeasonFlowPaysProRataReward() public {
        uint64 startTime = uint64(block.timestamp + 1);
        uint64 endTime = uint64(block.timestamp + 101);

        vm.startPrank(admin);
        token.approve(address(game), 500 ether);
        uint256 seasonId = game.createSeason(startTime, endTime, 500 ether);
        vm.stopPrank();

        vm.warp(startTime);

        vm.prank(alice);
        game.joinSeason(seasonId);

        vm.prank(admin);
        game.recordScore(seasonId, alice, 25);

        vm.warp(endTime);

        vm.prank(admin);
        game.finalizeSeason(seasonId);

        vm.prank(alice);
        uint256 reward = game.claimSeasonReward(seasonId);

        assertEq(reward, 500 ether);
        assertEq(token.balanceOf(treasury), 1 ether);
    }

    function testEquippedItemBoostsRecordedScore() public {
        uint64 startTime = uint64(block.timestamp + 1);
        uint64 endTime = uint64(block.timestamp + 101);

        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signMint(alice, 7, 2_000, "ipfs://blade.json", 0, deadline);
        uint256 itemId = items.mintWithSignature(alice, 7, 2_000, "ipfs://blade.json", 0, deadline, signature);

        vm.startPrank(admin);
        token.approve(address(game), 500 ether);
        uint256 seasonId = game.createSeason(startTime, endTime, 500 ether);
        vm.stopPrank();

        vm.warp(startTime);

        vm.startPrank(alice);
        game.joinSeason(seasonId);
        game.equipItem(seasonId, itemId);
        vm.stopPrank();

        vm.prank(admin);
        game.recordScore(seasonId, alice, 100);

        assertEq(game.scores(seasonId, alice), 120);
    }

    function testCannotJoinWithoutMinimumStake() public {
        address bob = address(0xB0B);
        vm.prank(admin);
        assertTrue(token.transfer(bob, 10 ether));

        uint64 startTime = uint64(block.timestamp + 1);
        uint64 endTime = uint64(block.timestamp + 101);

        vm.startPrank(admin);
        token.approve(address(game), 100 ether);
        uint256 seasonId = game.createSeason(startTime, endTime, 100 ether);
        vm.stopPrank();

        vm.warp(startTime);

        vm.startPrank(bob);
        token.approve(address(game), 1 ether);
        vm.expectRevert(AethiGame.TooLittleStake.selector);
        game.joinSeason(seasonId);
        vm.stopPrank();
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
