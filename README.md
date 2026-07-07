<p align="center">
  <img src="docs/assets/aet-banner.svg" alt="AET protocol banner" width="100%" />
</p>

<p align="center">
  <a href="#"><img alt="Solidity" src="https://img.shields.io/badge/Solidity-0.8.35-363636?style=for-the-badge&logo=solidity" /></a>
  <a href="#"><img alt="OpenZeppelin" src="https://img.shields.io/badge/OpenZeppelin-v5.6.1-4e5ee4?style=for-the-badge" /></a>
  <a href="https://basescan.org/address/0x000000000eAdb23d6d22585B9f50C3516028d262"><img alt="Base" src="https://img.shields.io/badge/Base-Mainnet-0052FF?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIxMiIgY3k9IjEyIiByPSIxMiIgZmlsbD0iIzAwNTJGRiIvPjwvc3ZnPg==" /></a>
  <a href="#"><img alt="License" src="https://img.shields.io/badge/License-MIT-244e5d?style=for-the-badge" /></a>
</p>

```
     █████╗ ███████╗████████╗
    ██╔══██╗██╔════╝╚══██╔══╝
    ███████║█████╗     ██║
    ██╔══██║██╔══╝     ██║
    ██║  ██║███████╗   ██║
    ╚═╝  ╚═╝╚══════╝   ╚═╝
    Seasonal Battle Protocol on Base
```

# AET

AET is a compact onchain game protocol for seasonal play, deployed on **Base** (Chain ID `8453`).

> **Official AET Token:** [`0x000000000eAdb23d6d22585B9f50C3516028d262`](https://basescan.org/address/0x000000000eAdb23d6d22585B9f50C3516028d262) on Base Network

Players stake AET, mint signed item NFTs, join live seasons, commit battle actions, earn resolved score, and claim rewards from season pools. The contracts keep token supply, item ownership, staking access, game state, and auxiliary rewards separated.

<p align="center">
  <img src="docs/assets/protocol-map.svg" alt="AET protocol map" width="100%" />
</p>

## Official Deployment — Base Mainnet

| Contract | Address |
| --- | --- |
| **AETToken** | [`0x000000000eAdb23d6d22585B9f50C3516028d262`](https://basescan.org/address/0x000000000eAdb23d6d22585B9f50C3516028d262) |
| AETItems | [`0xec1AaACB059094F6B276E269A3CAd063Ce854c42`](https://basescan.org/address/0xec1AaACB059094F6B276E269A3CAd063Ce854c42) |
| AETStaking | [`0x622Da894dBFa2738F21EA1D544a0ee7bf1aD91AC`](https://basescan.org/address/0x622Da894dBFa2738F21EA1D544a0ee7bf1aD91AC) |
| AETGame | [`0x2657e9e8444227FB800216c6c70a6D74B0D0196b`](https://basescan.org/address/0x2657e9e8444227FB800216c6c70a6D74B0D0196b) |
| AETRewardDistributor | [`0x115dC0562E85a897c7C1fD61C994b78Ca0900BA3`](https://basescan.org/address/0x115dC0562E85a897c7C1fD61C994b78Ca0900BA3) |

> **Network:** Base Mainnet (Chain ID `8453`)
> **Token Name:** AET | **Symbol:** AET
> **Admin:** `0x000000000Bd34154377F01f1809dDa632c265e16`

## Protocol

| Module | Contract | Purpose |
| --- | --- | --- |
| Token | `AETToken` | Capped ERC20 with permit, pausing, and role-gated minting. |
| Items | `AETItems` | ERC721 equipment with EIP-712 mint authorizations, classes, action affinity, and finite charges. |
| Staking | `AETStaking` | Single-token staking vault with reward periods, reward-per-share accounting, and unstake cooldown. |
| Game | `AETGame` | Season lifecycle, stake snapshots, battle action commits, signed result resolution, claims, cancellation, and dust sweep. |
| Rewards | `AETRewardDistributor` | Controlled vault for direct reward distributions outside season pools. |

## Gameplay Loop

```text
Acquire AET
    ↓
Stake for access
    ↓
Mint signed equipment
    ↓
Join a season
    ↓
Equip item and commit battle action
    ↓
Resolve signed match result
    ↓
Claim season rewards
```

## Design

- Token and item logic use audited OpenZeppelin Contracts primitives.
- Item minting uses typed signatures, account nonces, deadlines, and capped boost power.
- Staking rewards use accumulated reward-per-share accounting and do not iterate over users.
- Season parameters and player stake are snapshotted so active seasons are not changed by later config updates.
- Battle rounds require player action commits and signed match results before resolution.
- Items can carry classes, action affinity, finite charges, and bounded boost power.
- Season rewards are escrowed when a season is created and paid pro-rata after finalization.
- Season managers can cancel not-yet-started seasons and sweep reward dust after the claim window.
- Privileged actions are split across admin, signer, operator, season, reward, and pause roles.
- The game contract does not use block values for randomness.

## Repository

```text
src/
  game/        Season and battle protocol
  interfaces/
  items/       Equipment NFTs
  rewards/     Direct reward vault
  staking/     Staking vault
  token/       AET token

docs/
  architecture.md
  game-mechanics.md
  economics.md
  operations.md
  threat-model.md
```

## Deployment

Copy `.env.example` to `.env`, fill `PRIVATE_KEY`, `ETHERSCAN_API_KEY`, and role addresses, then deploy to Base mainnet:

```bash
source .env
forge script script/DeployAET.s.sol:DeployAET --rpc-url base --chain 8453 --broadcast --verify --verifier etherscan --verifier-url "$ETHERSCAN_API_URL" --etherscan-api-key "$ETHERSCAN_API_KEY" -vvvv
```

The script deploys the five core contracts, connects `AETItems` to `AETGame`, grants the game item-consumer permissions, and hands protocol roles to `AET_ADMIN`.

> **Note:** The AET token is deployed first to secure the vanity address `0x000000000eAdb23d6d22585B9f50C3516028d262`.

## Documentation

- [Architecture](docs/architecture.md)
- [Game mechanics](docs/game-mechanics.md)
- [Economics](docs/economics.md)
- [Operations](docs/operations.md)
- [Threat model](docs/threat-model.md)
- [Roadmap](docs/roadmap.md)
- [Base Mainnet Deployment](docs/deployments/base-mainnet.md)

## Assets

- [Logo mark](docs/assets/aet-logo-mark.svg)
- [Wordmark](docs/assets/aet-wordmark.svg)
- [Banner](docs/assets/aet-banner.svg)
- [Social preview](docs/assets/aet-social-preview.svg)

## Source Code

- GitHub: [https://github.com/xelioodev/AET](https://github.com/xelioodev/AET)

## Status

Experimental. Review roles, monitoring, invariant tests, and independent audit coverage before production use.
