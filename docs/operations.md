# Operations

This document covers live protocol operation.

## Roles

Use separate accounts for:

- admin
- item signer
- game operator
- season manager
- reward manager
- distributor
- pauser

Admin roles should be controlled by a multisig. Hot operational keys should only hold narrow roles.

## Base Mainnet Deployment

Use Base mainnet chain ID `8453`. The default RPC alias is `base`, backed by `BASE_MAINNET_RPC_URL` in `.env`.

Required deployment variables:

- `BASE_MAINNET_RPC_URL`: Base mainnet RPC endpoint
- `ETHERSCAN_API_URL`: Etherscan v2 API endpoint, default `https://api.etherscan.io/v2/api?chainid=8453`
- `PRIVATE_KEY`: deployer key with ETH on Base for gas
- `ETHERSCAN_API_KEY`: Etherscan v2 API key used for Base verification
- `AET_ADMIN`: multisig or role-admin address
- `AET_TREASURY`: fee recipient
- `AET_INITIAL_RECIPIENT`: recipient for initial AET supply

Deploy and verify:

```bash
source .env
forge script script/DeployAET.s.sol:DeployAET --rpc-url base --chain 8453 --broadcast --verify --verifier etherscan --verifier-url "$ETHERSCAN_API_URL" --etherscan-api-key "$ETHERSCAN_API_KEY" -vvvv
```

The deployer is used as temporary setup admin so the script can wire contracts safely. If `AET_ADMIN` is different, the script grants protocol roles to `AET_ADMIN` and renounces the deployer's roles before finishing.

## Season Runbook

1. Fund the season reward pool.
2. Create the season with start and end timestamps.
3. Monitor joins and committed actions.
4. Sign battle results offchain.
5. Submit results individually or in batches.
6. Finalize after season end.
7. Monitor claims through the claim window.
8. Sweep dust after the claim window closes.

## Incident Handling

If an item signer is compromised:

- revoke `ITEM_SIGNER_ROLE`
- rotate signer
- monitor unusual item mints

If a game operator is compromised:

- revoke `GAME_OPERATOR_ROLE`
- pause game actions if needed
- review signed battle results and pending submissions

If a season is malformed before meaningful score is recorded:

- cancel the season
- refund the reward pool to the selected recipient

## Monitoring

Track:

- role changes
- item mints
- season creation and cancellation
- battle action commits
- battle resolutions
- season finalization
- claims and dust sweeps
