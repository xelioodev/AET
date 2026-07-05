// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAethiItems
/// @notice Minimal item NFT interface consumed by the Aethi game layer.
interface IAethiItems {
    /// @notice Returns the owner of an item NFT.
    /// @param tokenId Item token identifier.
    /// @return The item owner.
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Returns the gameplay power value assigned to an item.
    /// @param tokenId Item token identifier.
    /// @return Power in basis points applied as a score boost.
    function itemPower(uint256 tokenId) external view returns (uint256);
}
