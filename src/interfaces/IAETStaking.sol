// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title IAETStaking
/// @notice Minimal staking interface consumed by the game layer.
interface IAETStaking {
    /// @notice Returns the currently staked token balance for an account.
    /// @param account The account whose staking power is being queried.
    /// @return The amount of AET currently staked by `account`.
    function stakedBalanceOf(address account) external view returns (uint256);
}
