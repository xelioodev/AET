// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IAethiItems} from "../interfaces/IAethiItems.sol";
import {IAethiStaking} from "../interfaces/IAethiStaking.sol";

/// @title AethiGame
/// @notice Season-based GameFi coordinator using staked AETHI as player power.
/// @dev Scores are operator-recorded in the MVP to avoid insecure on-chain randomness.
contract AethiGame is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role allowed to create and finalize seasons.
    bytes32 public constant SEASON_MANAGER_ROLE = keccak256("SEASON_MANAGER_ROLE");

    /// @notice Role allowed to record player scores.
    bytes32 public constant GAME_OPERATOR_ROLE = keccak256("GAME_OPERATOR_ROLE");

    /// @notice Role allowed to pause and unpause game actions.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Token used for fees and season rewards.
    IERC20 public immutable token;

    /// @notice Staking contract used to verify player power.
    IAethiStaking public immutable staking;

    /// @notice Optional item collection used for season equipment boosts.
    IAethiItems public itemCollection;

    /// @notice Treasury receiving season entry fees.
    address public treasury;

    /// @notice Minimum staked AETHI required to join a season.
    uint256 public minStakeToPlay;

    /// @notice Fee paid in AETHI to join a season.
    uint256 public entryFee;

    /// @notice Next season identifier.
    uint256 public nextSeasonId = 1;

    struct Season {
        uint64 startTime;
        uint64 endTime;
        uint256 rewardPool;
        uint256 totalScore;
        bool finalized;
    }

    mapping(uint256 seasonId => Season season) public seasons;
    mapping(uint256 seasonId => mapping(address player => bool joined)) public hasJoined;
    mapping(uint256 seasonId => mapping(address player => uint256 score)) public scores;
    mapping(uint256 seasonId => mapping(address player => bool claimed)) public hasClaimed;
    mapping(uint256 seasonId => mapping(address player => uint256 tokenId)) public equippedItems;

    event SeasonCreated(uint256 indexed seasonId, uint64 startTime, uint64 endTime, uint256 rewardPool);
    event SeasonJoined(uint256 indexed seasonId, address indexed player);
    event ItemCollectionUpdated(address indexed itemCollection);
    event ItemEquipped(uint256 indexed seasonId, address indexed player, uint256 indexed tokenId, uint256 powerBps);
    event ScoreRecorded(uint256 indexed seasonId, address indexed player, uint256 scoreDelta, uint256 totalPlayerScore);
    event SeasonFinalized(uint256 indexed seasonId, uint256 totalScore);
    event SeasonRewardClaimed(uint256 indexed seasonId, address indexed player, uint256 amount);
    event GameConfigUpdated(address treasury, uint256 minStakeToPlay, uint256 entryFee);

    error AlreadyClaimed();
    error AlreadyJoined();
    error InvalidAmount();
    error InvalidSeason();
    error SeasonActive();
    error SeasonClosed();
    error SeasonNotFinalized();
    error TooLittleStake();
    error ZeroAddress();

    /// @param token_ AETHI token used by the game.
    /// @param staking_ Staking contract used for player eligibility.
    /// @param treasury_ Account receiving entry fees.
    /// @param admin Account receiving admin, season manager, operator, and pauser roles.
    /// @param minStakeToPlay_ Initial minimum stake required to join.
    /// @param entryFee_ Initial entry fee.
    constructor(
        IERC20 token_,
        IAethiStaking staking_,
        address treasury_,
        address admin,
        uint256 minStakeToPlay_,
        uint256 entryFee_
    ) {
        if (
            address(token_) == address(0) || address(staking_) == address(0) || treasury_ == address(0)
                || admin == address(0)
        ) {
            revert ZeroAddress();
        }

        token = token_;
        staking = staking_;
        treasury = treasury_;
        minStakeToPlay = minStakeToPlay_;
        entryFee = entryFee_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SEASON_MANAGER_ROLE, admin);
        _grantRole(GAME_OPERATOR_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Creates a new season and escrows its reward pool.
    /// @param startTime Timestamp when players can join and score.
    /// @param endTime Timestamp when the season stops accepting scores.
    /// @param rewardPool Reward amount transferred from the caller.
    /// @return seasonId Identifier of the created season.
    function createSeason(uint64 startTime, uint64 endTime, uint256 rewardPool)
        external
        nonReentrant
        onlyRole(SEASON_MANAGER_ROLE)
        returns (uint256 seasonId)
    {
        if (startTime >= endTime || endTime <= block.timestamp || rewardPool == 0) {
            revert InvalidSeason();
        }

        seasonId = nextSeasonId++;
        seasons[seasonId] =
            Season({startTime: startTime, endTime: endTime, rewardPool: rewardPool, totalScore: 0, finalized: false});

        token.safeTransferFrom(msg.sender, address(this), rewardPool);
        emit SeasonCreated(seasonId, startTime, endTime, rewardPool);
    }

    /// @notice Joins an active season after meeting the staking requirement.
    /// @param seasonId Season to join.
    function joinSeason(uint256 seasonId) external nonReentrant whenNotPaused {
        Season memory season = seasons[seasonId];
        if (!_isActive(season)) {
            revert SeasonClosed();
        }
        if (hasJoined[seasonId][msg.sender]) {
            revert AlreadyJoined();
        }
        if (staking.stakedBalanceOf(msg.sender) < minStakeToPlay) {
            revert TooLittleStake();
        }

        hasJoined[seasonId][msg.sender] = true;

        if (entryFee != 0) {
            token.safeTransferFrom(msg.sender, treasury, entryFee);
        }

        emit SeasonJoined(seasonId, msg.sender);
    }

    /// @notice Equips an owned item for the current season.
    /// @param seasonId Active season receiving the item boost.
    /// @param tokenId Item NFT identifier.
    function equipItem(uint256 seasonId, uint256 tokenId) external whenNotPaused {
        Season memory season = seasons[seasonId];
        if (!_isActive(season)) {
            revert SeasonClosed();
        }
        if (!hasJoined[seasonId][msg.sender]) {
            revert InvalidSeason();
        }
        if (address(itemCollection) == address(0)) {
            revert ZeroAddress();
        }
        if (itemCollection.ownerOf(tokenId) != msg.sender) {
            revert InvalidSeason();
        }

        uint256 powerBps = itemCollection.itemPower(tokenId);
        equippedItems[seasonId][msg.sender] = tokenId;

        emit ItemEquipped(seasonId, msg.sender, tokenId, powerBps);
    }

    /// @notice Records score earned by a player in a season.
    /// @param seasonId Season receiving the score.
    /// @param player Player whose score is updated.
    /// @param scoreDelta Score to add.
    function recordScore(uint256 seasonId, address player, uint256 scoreDelta)
        external
        whenNotPaused
        onlyRole(GAME_OPERATOR_ROLE)
    {
        Season storage season = seasons[seasonId];
        if (!_isActive(season)) {
            revert SeasonClosed();
        }
        if (player == address(0)) {
            revert ZeroAddress();
        }
        if (!hasJoined[seasonId][player]) {
            revert InvalidSeason();
        }
        if (scoreDelta == 0) {
            revert InvalidAmount();
        }

        uint256 boostedScore = _boostedScore(seasonId, player, scoreDelta);
        scores[seasonId][player] += boostedScore;
        season.totalScore += boostedScore;

        emit ScoreRecorded(seasonId, player, boostedScore, scores[seasonId][player]);
    }

    /// @notice Finalizes a season after it has ended.
    /// @param seasonId Season to finalize.
    function finalizeSeason(uint256 seasonId) external onlyRole(SEASON_MANAGER_ROLE) {
        Season storage season = seasons[seasonId];
        if (season.endTime == 0) {
            revert InvalidSeason();
        }
        if (season.finalized) {
            revert SeasonClosed();
        }
        if (block.timestamp < season.endTime) {
            revert SeasonActive();
        }

        season.finalized = true;
        emit SeasonFinalized(seasonId, season.totalScore);
    }

    /// @notice Claims the caller's pro-rata season reward.
    /// @param seasonId Finalized season to claim from.
    /// @return reward Amount transferred to the caller.
    function claimSeasonReward(uint256 seasonId) external nonReentrant returns (uint256 reward) {
        Season storage season = seasons[seasonId];
        if (!season.finalized) {
            revert SeasonNotFinalized();
        }
        if (hasClaimed[seasonId][msg.sender]) {
            revert AlreadyClaimed();
        }

        hasClaimed[seasonId][msg.sender] = true;

        uint256 playerScore = scores[seasonId][msg.sender];
        if (playerScore == 0 || season.totalScore == 0) {
            return 0;
        }

        reward = (season.rewardPool * playerScore) / season.totalScore;
        token.safeTransfer(msg.sender, reward);

        emit SeasonRewardClaimed(seasonId, msg.sender, reward);
    }

    /// @notice Updates game-level economic settings.
    /// @param treasury_ Treasury receiving entry fees.
    /// @param minStakeToPlay_ Minimum stake required to join seasons.
    /// @param entryFee_ Entry fee charged when joining seasons.
    function setGameConfig(address treasury_, uint256 minStakeToPlay_, uint256 entryFee_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (treasury_ == address(0)) {
            revert ZeroAddress();
        }

        treasury = treasury_;
        minStakeToPlay = minStakeToPlay_;
        entryFee = entryFee_;

        emit GameConfigUpdated(treasury_, minStakeToPlay_, entryFee_);
    }

    /// @notice Sets the item NFT collection used for equipment boosts.
    /// @param itemCollection_ Item collection contract.
    function setItemCollection(IAethiItems itemCollection_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(itemCollection_) == address(0)) {
            revert ZeroAddress();
        }

        itemCollection = itemCollection_;
        emit ItemCollectionUpdated(address(itemCollection_));
    }

    /// @notice Pauses joins and score recording.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resumes joins and score recording.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _isActive(Season memory season) internal view returns (bool) {
        return season.startTime <= block.timestamp && block.timestamp < season.endTime && !season.finalized;
    }

    function _boostedScore(uint256 seasonId, address player, uint256 baseScore) internal view returns (uint256) {
        uint256 tokenId = equippedItems[seasonId][player];
        if (tokenId == 0) {
            return baseScore;
        }

        uint256 powerBps = itemCollection.itemPower(tokenId);
        return (baseScore * (10_000 + powerBps)) / 10_000;
    }
}
