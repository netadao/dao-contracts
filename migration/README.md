# NETADAO 

## Step 1: re-upload contracts
to get the dao contracts being used:
```
junod config node     https://juno-rpc.lavenderfive.com:443
junod q wasm code 627 ./current-contracts/cw-proposal-single.wasm
junod q wasm code 431 ./current-contracts/cw20-staked-balance-voting.wasm
junod q wasm code 432 ./current-contracts/cw-core.wasm
junod q wasm code 430 ./current-contracts/cw20-stake.wasm
junod q wasm code 1   ./current-contracts/cw20.wasm
junod q wasm code 429 ./current-contracts/cw4-voting.wasm
```
to get the v1 contracts needed:
```
# build custom proposal contract for migration
cd ../
# ...

```
to get the v2 contracts needed:
```sh
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/cw20_stake.wasm 
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/dao_dao_core.wasm 
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/dao_migrator.wasm 
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/dao_pre_propose_single.wasm
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/dao_proposal_single.wasm 
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/dao_voting_cw20_staked.wasm 
wget https://github.com/DA0-DA0/dao-contracts/releases/download/v2.4.2/dao_voting_cw4.wasm 
```
## Step 2: re-create Neta DAO instance
to recreate the dao, we need the dao framework as well as an external cw20 token created

## Step 3: migrate module back to v1
this is the migration on the custom proposal contract that restores compatiblility with the v1 -> v2 migration workflow dao-dao has implemented. This can be done through governance, or by the contract admin.

## Step 5: migrate dao framework from v1 -> v2

## Syntax Bug: Incosistent internal proposal-id syntaxt for pre-propose & proposal contracts

Testing proposals post v1-> v2 migration revealed logs emitted from the pre-propose module containing a proposal id incosistent with the correct proposal id. 

This may introduce complexity for any custom pre-propose logic that may be introduced in the future, however does not seem to impact any of the voting workflow, inculding any refunding necessary for proposal deposits. (confirmed in tests)

### Remedy 
A future migration of the v2 proposal contract to internally reflect the correct value for the pre-proposal contract may be necessary. This approach avoids customizing the existing v1-v2 migration workflow already production ready for daos. 