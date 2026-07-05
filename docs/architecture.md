# Aethi Architecture

Aethi is a modular GameFi protocol for season-based gameplay. The system keeps token economics, item ownership, staking access, score management, and reward distribution in separate contracts.

## Game model

Aethi seasons are competitive campaigns. Players stake AETHI to qualify for participation, mint signed item NFTs, equip one item for score boosts, and compete for a funded reward pool.

The game avoids using block values as randomness. Season progress and score updates are recorded by a trusted operator in the current version. This model is explicit and can be upgraded later with signed score attestations, oracle-backed game results, or verifiable off-chain proofs.

## Player flow

```text
Player
  ├─ stakes AETHI in AethiStaking
  ├─ receives signed item authorization off-chain
  ├─ mints item NFT in AethiItems
  ├─ joins a season in AethiGame
  ├─ equips one item for the season
  └─ claims token rewards after season finalization
```

## Contract overview

### AethiToken

`AethiToken` is the protocol ERC20 token.

Features:

- immutable supply cap
- initial supply mint
- role-gated minting
- pausable transfers
- ERC20 Permit support

### AethiItems

`AethiItems` is the ERC721 item collection used by the game.

Items can represent game passes, score modifiers, badges, access objects, or campaign rewards. Minting requires an EIP-712 signature from an account with `ITEM_SIGNER_ROLE`.

The signed mint payload includes:

- player address
- item type
- item power in basis points
- metadata URI hash
- player nonce
- deadline

This protects against replay, limits stale authorizations, and allows the game backend or operations process to issue item rewards without exposing admin privileges.

### AethiStaking

`AethiStaking` is a single-token staking vault.

It serves two purposes:

- eligibility for season participation
- time-based AETHI rewards

Rewards use accumulated reward-per-share accounting. Stake, unstake, and claim operations do not loop through all users.

### AethiGame

`AethiGame` manages competitive seasons.

A season contains:

- start timestamp
- end timestamp
- escrowed reward pool
- total score
- finalized state

Players must satisfy the minimum staking requirement before joining. A joined player can equip one item NFT. When an operator records score, the equipped item boost is applied:

```text
boostedScore = baseScore * (10_000 + itemPowerBps) / 10_000
```

After the season ends, the season manager finalizes the season. Player rewards are calculated pro-rata:

```text
reward = seasonRewardPool * playerScore / totalSeasonScore
```

### AethiRewardDistributor

`AethiRewardDistributor` is a controlled reward vault for bonus distributions, campaigns, grants, and operational reward programs. It is intentionally separate from season reward pools.

## System Map

```text
AethiToken
  ├─ staking token for AethiStaking
  ├─ reward token for AethiStaking
  ├─ fee and reward token for AethiGame
  └─ payout token for AethiRewardDistributor

AethiItems
  └─ read by AethiGame for item ownership and score boost power

AethiStaking
  └─ read by AethiGame for season eligibility
```

## Roles

| Role | Contract | Capability |
| --- | --- | --- |
| `DEFAULT_ADMIN_ROLE` | all role-based contracts | Grants and revokes roles. |
| `MINTER_ROLE` | `AethiToken` | Mints AETHI up to the cap. |
| `PAUSER_ROLE` | token, items, staking, game, distributor | Pauses emergency-sensitive actions. |
| `ITEM_SIGNER_ROLE` | `AethiItems` | Signs item mint authorizations. |
| `METADATA_MANAGER_ROLE` | `AethiItems` | Updates item metadata URI. |
| `REWARD_MANAGER_ROLE` | `AethiStaking` | Funds staking reward periods. |
| `SEASON_MANAGER_ROLE` | `AethiGame` | Creates and finalizes seasons. |
| `GAME_OPERATOR_ROLE` | `AethiGame` | Records player score. |
| `DISTRIBUTOR_ROLE` | `AethiRewardDistributor` | Sends funded bonus rewards. |

## Deployment

The deploy script creates:

1. `AethiToken`
2. `AethiItems`
3. `AethiStaking`
4. `AethiGame`
5. `AethiRewardDistributor`

It also connects `AethiItems` to `AethiGame` so the game can read item ownership and item power.
