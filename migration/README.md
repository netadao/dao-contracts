# NETADAO 

## Step 1: re-upload contracts
to get the dao contracts being used:
```
junod q wasm code 432 cw-core.wasm
junod q wasm code 431 cw20-staked-balance-voting.wasm
junod q wasm code 627 cw-proposal-single.wasm
junod q wasm code 430 cw20-stake.wasm
junod q wasm code 1 cw20.wasm
```
to get the v1 contracts needed:
```
# cw_proposal_single
# pre_proposal_single
# ...
```
to get the v2 contracts needed:
```

```
## Step 2: re-create Neta DAO instance
to recreate the dao, we need the dao framework as well as an external cw20 token created

## Step 3: migrate module back to v1
this is the migration on the custom proposal contract that restores compatiblility with the v1 -> v2 migration workflow dao-dao has implemented. This can be done through governance, or by the contract admin.

## Step 5: migrate dao framework from v1 -> v2
