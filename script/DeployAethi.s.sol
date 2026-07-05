// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {AethiGame} from "../src/game/AethiGame.sol";
import {AethiItems} from "../src/items/AethiItems.sol";
import {AethiRewardDistributor} from "../src/rewards/AethiRewardDistributor.sol";
import {AethiStaking} from "../src/staking/AethiStaking.sol";
import {AethiToken} from "../src/token/AethiToken.sol";

/// @title DeployAethi
/// @notice Deploys the Aethi token, item collection, staking vault, game coordinator, and reward distributor.
contract DeployAethi is Script {
    uint256 internal constant DEFAULT_INITIAL_SUPPLY = 100_000_000 ether;
    uint256 internal constant DEFAULT_SUPPLY_CAP = 1_000_000_000 ether;
    uint256 internal constant DEFAULT_REWARDS_DURATION = 30 days;
    uint256 internal constant DEFAULT_MIN_STAKE_TO_PLAY = 100 ether;
    uint256 internal constant DEFAULT_ENTRY_FEE = 1 ether;

    /// @notice Deploys all core Aethi MVP contracts.
    function run()
        external
        returns (
            AethiToken token,
            AethiItems items,
            AethiStaking staking,
            AethiGame game,
            AethiRewardDistributor rewardDistributor
        )
    {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envOr("AETHI_ADMIN", vm.addr(deployerKey));
        address treasury = vm.envOr("AETHI_TREASURY", admin);
        address initialRecipient = vm.envOr("AETHI_INITIAL_RECIPIENT", admin);

        uint256 initialSupply = vm.envOr("AETHI_INITIAL_SUPPLY", DEFAULT_INITIAL_SUPPLY);
        uint256 supplyCap = vm.envOr("AETHI_SUPPLY_CAP", DEFAULT_SUPPLY_CAP);
        uint256 rewardsDuration = vm.envOr("AETHI_REWARDS_DURATION", DEFAULT_REWARDS_DURATION);
        uint256 minStakeToPlay = vm.envOr("AETHI_MIN_STAKE_TO_PLAY", DEFAULT_MIN_STAKE_TO_PLAY);
        uint256 entryFee = vm.envOr("AETHI_ENTRY_FEE", DEFAULT_ENTRY_FEE);

        vm.startBroadcast(deployerKey);

        token = new AethiToken(admin, initialRecipient, initialSupply, supplyCap);
        items = new AethiItems(admin);
        staking = new AethiStaking(token, token, admin, rewardsDuration);
        game = new AethiGame(token, staking, treasury, admin, minStakeToPlay, entryFee);
        game.setItemCollection(items);
        rewardDistributor = new AethiRewardDistributor(token, admin);

        vm.stopBroadcast();
    }
}
