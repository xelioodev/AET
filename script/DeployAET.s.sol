// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";

import {AETGame} from "../src/game/AETGame.sol";
import {AETItems} from "../src/items/AETItems.sol";
import {AETRewardDistributor} from "../src/rewards/AETRewardDistributor.sol";
import {AETStaking} from "../src/staking/AETStaking.sol";
import {AETToken} from "../src/token/AETToken.sol";

/// @title DeployAET
/// @notice Deploys the AET token, item collection, staking vault, game coordinator, and reward distributor.
contract DeployAET is Script {
    uint256 internal constant DEFAULT_INITIAL_SUPPLY = 100_000_000 ether;
    uint256 internal constant DEFAULT_SUPPLY_CAP = 1_000_000_000 ether;
    uint256 internal constant DEFAULT_REWARDS_DURATION = 30 days;
    uint256 internal constant DEFAULT_UNSTAKE_COOLDOWN = 1 days;
    uint256 internal constant DEFAULT_MIN_STAKE_TO_PLAY = 100 ether;
    uint256 internal constant DEFAULT_ENTRY_FEE = 1 ether;
    uint256 internal constant DEFAULT_STAKE_BOOST_CAP_BPS = 2_000;
    uint256 internal constant DEFAULT_MAX_SEASON_ROUND = 1_000;
    uint256 internal constant DEFAULT_ACTION_TIMEOUT = 15 minutes;
    uint256 internal constant DEFAULT_CLAIM_PERIOD = 7 days;

    struct DeployConfig {
        address admin;
        address treasury;
        address initialRecipient;
        uint256 initialSupply;
        uint256 supplyCap;
        uint256 rewardsDuration;
        uint256 unstakeCooldown;
        uint256 minStakeToPlay;
        uint256 entryFee;
        uint256 stakeBoostCapBps;
        uint256 maxSeasonRound;
        uint256 actionTimeout;
        uint256 claimPeriod;
    }

    /// @notice Deploys all core AET contracts.
    function run()
        external
        returns (
            AETToken token,
            AETItems items,
            AETStaking staking,
            AETGame game,
            AETRewardDistributor rewardDistributor
        )
    {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        DeployConfig memory config = _loadConfig(deployerKey);

        vm.startBroadcast(deployerKey);

        token = new AETToken(deployer, config.initialRecipient, config.initialSupply, config.supplyCap);
        items = new AETItems(deployer);
        staking = new AETStaking(token, token, deployer, config.rewardsDuration, config.unstakeCooldown);
        game = new AETGame(
            token,
            staking,
            config.treasury,
            deployer,
            config.minStakeToPlay,
            config.entryFee,
            config.stakeBoostCapBps,
            config.maxSeasonRound,
            config.actionTimeout,
            config.claimPeriod
        );
        game.setItemCollection(items);
        items.grantRole(items.ITEM_CONSUMER_ROLE(), address(game));
        rewardDistributor = new AETRewardDistributor(token, deployer);

        _handoverRoles(token, items, staking, game, rewardDistributor, deployer, config.admin);

        vm.stopBroadcast();
    }

    function _loadConfig(uint256 deployerKey) internal view returns (DeployConfig memory config) {
        config.admin = vm.envOr("AET_ADMIN", vm.addr(deployerKey));
        config.treasury = vm.envOr("AET_TREASURY", config.admin);
        config.initialRecipient = vm.envOr("AET_INITIAL_RECIPIENT", config.admin);
        config.initialSupply = vm.envOr("AET_INITIAL_SUPPLY", DEFAULT_INITIAL_SUPPLY);
        config.supplyCap = vm.envOr("AET_SUPPLY_CAP", DEFAULT_SUPPLY_CAP);
        config.rewardsDuration = vm.envOr("AET_REWARDS_DURATION", DEFAULT_REWARDS_DURATION);
        config.unstakeCooldown = vm.envOr("AET_UNSTAKE_COOLDOWN", DEFAULT_UNSTAKE_COOLDOWN);
        config.minStakeToPlay = vm.envOr("AET_MIN_STAKE_TO_PLAY", DEFAULT_MIN_STAKE_TO_PLAY);
        config.entryFee = vm.envOr("AET_ENTRY_FEE", DEFAULT_ENTRY_FEE);
        config.stakeBoostCapBps = vm.envOr("AET_STAKE_BOOST_CAP_BPS", DEFAULT_STAKE_BOOST_CAP_BPS);
        config.maxSeasonRound = vm.envOr("AET_MAX_SEASON_ROUND", DEFAULT_MAX_SEASON_ROUND);
        config.actionTimeout = vm.envOr("AET_ACTION_TIMEOUT", DEFAULT_ACTION_TIMEOUT);
        config.claimPeriod = vm.envOr("AET_CLAIM_PERIOD", DEFAULT_CLAIM_PERIOD);
    }

    function _handoverRoles(
        AETToken token,
        AETItems items,
        AETStaking staking,
        AETGame game,
        AETRewardDistributor rewardDistributor,
        address deployer,
        address admin
    ) internal {
        if (admin == deployer) {
            return;
        }

        token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
        token.grantRole(token.MINTER_ROLE(), admin);
        token.grantRole(token.PAUSER_ROLE(), admin);
        token.renounceRole(token.MINTER_ROLE(), deployer);
        token.renounceRole(token.PAUSER_ROLE(), deployer);
        token.renounceRole(token.DEFAULT_ADMIN_ROLE(), deployer);

        items.grantRole(items.DEFAULT_ADMIN_ROLE(), admin);
        items.grantRole(items.ITEM_SIGNER_ROLE(), admin);
        items.grantRole(items.PAUSER_ROLE(), admin);
        items.grantRole(items.METADATA_MANAGER_ROLE(), admin);
        items.grantRole(items.ITEM_CONSUMER_ROLE(), admin);
        items.renounceRole(items.ITEM_SIGNER_ROLE(), deployer);
        items.renounceRole(items.PAUSER_ROLE(), deployer);
        items.renounceRole(items.METADATA_MANAGER_ROLE(), deployer);
        items.renounceRole(items.ITEM_CONSUMER_ROLE(), deployer);
        items.renounceRole(items.DEFAULT_ADMIN_ROLE(), deployer);

        staking.grantRole(staking.DEFAULT_ADMIN_ROLE(), admin);
        staking.grantRole(staking.REWARD_MANAGER_ROLE(), admin);
        staking.grantRole(staking.PAUSER_ROLE(), admin);
        staking.renounceRole(staking.REWARD_MANAGER_ROLE(), deployer);
        staking.renounceRole(staking.PAUSER_ROLE(), deployer);
        staking.renounceRole(staking.DEFAULT_ADMIN_ROLE(), deployer);

        game.grantRole(game.DEFAULT_ADMIN_ROLE(), admin);
        game.grantRole(game.SEASON_MANAGER_ROLE(), admin);
        game.grantRole(game.GAME_OPERATOR_ROLE(), admin);
        game.grantRole(game.PAUSER_ROLE(), admin);
        game.renounceRole(game.SEASON_MANAGER_ROLE(), deployer);
        game.renounceRole(game.GAME_OPERATOR_ROLE(), deployer);
        game.renounceRole(game.PAUSER_ROLE(), deployer);
        game.renounceRole(game.DEFAULT_ADMIN_ROLE(), deployer);

        rewardDistributor.grantRole(rewardDistributor.DEFAULT_ADMIN_ROLE(), admin);
        rewardDistributor.grantRole(rewardDistributor.DISTRIBUTOR_ROLE(), admin);
        rewardDistributor.grantRole(rewardDistributor.PAUSER_ROLE(), admin);
        rewardDistributor.renounceRole(rewardDistributor.DISTRIBUTOR_ROLE(), deployer);
        rewardDistributor.renounceRole(rewardDistributor.PAUSER_ROLE(), deployer);
        rewardDistributor.renounceRole(rewardDistributor.DEFAULT_ADMIN_ROLE(), deployer);
    }
}
