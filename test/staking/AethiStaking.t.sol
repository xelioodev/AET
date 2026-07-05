// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {AethiStaking} from "../../src/staking/AethiStaking.sol";
import {AethiToken} from "../../src/token/AethiToken.sol";

contract AethiStakingTest is Test {
    AethiToken internal token;
    AethiStaking internal staking;

    address internal admin = address(0xA11CE);
    address internal alice = address(0xA1);

    function setUp() public {
        token = new AethiToken(admin, admin, 10_000 ether, 100_000 ether);
        staking = new AethiStaking(token, token, admin, 100 seconds);

        vm.startPrank(admin);
        assertTrue(token.transfer(alice, 1_000 ether));
        token.approve(address(staking), 1_000 ether);
        staking.fundRewards(100 ether);
        vm.stopPrank();
    }

    function testStakeAccruesAndClaimsRewards() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 50 seconds);
        assertApproxEqAbs(staking.pendingRewards(alice), 50 ether, 1 wei);

        vm.prank(alice);
        uint256 claimed = staking.claim();

        assertApproxEqAbs(claimed, 50 ether, 1 wei);
        assertApproxEqAbs(token.balanceOf(alice), 950 ether, 1 wei);
    }

    function testUnstakeReturnsPrincipal() public {
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        staking.unstake(40 ether);
        vm.stopPrank();

        assertEq(staking.stakedBalanceOf(alice), 60 ether);
        assertEq(token.balanceOf(alice), 940 ether);
    }
}
