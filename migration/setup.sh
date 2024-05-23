# Workflow 
admin_addr=
binary=junod

## Old NetaDAO Contracts
cw_core_code_id=1
cw20_code_id=2
cw20_staked_balance_voting_code_id=3
proposal_module_code_id=5
staking_module_code_id=6

## Existing V1 Contracts
proposal_code_id=17
cw4_voting_code_id=4
cw20_stake=7

## New V2 Contracts
v2_migrator_code_id=32
v2_pre_propose_code_id=36
v2_proposal_single_code_id=40
v2_cw4_voting_code_id=45
v2_cw20_stake_code_id=21
v2_cw20_staked_balances_voting_code_id=44
v2_dao_code_id=31

################## 1. Store All Contracts ##################

################## 2. Instantiate Mock NETA CW20 ##################
MSG=$(cat <<EOF
{
    "name": "NETA",
    "symbol": "NETA",
    "decimals": 6,
    "initial_balances": [
        {
            "address": "$admin_addr",
            "amount": "32950000000"
        }
    ],
    "marketing": {
        "marketing": "$admin_addr",
        "description": "Decentralized Store of Value",
        "logo": {
            "url": "https://neta.money/NETA_logo.svg"
        },
        "project": "https://neta.money"
    }
}
EOF
)

cw20_i=$($binary tx wasm i $cw20_code_id "$MSG" --from test1 --gas auto --gas-adjustment 2 --gas-prices 0.05ujuno  --label="cw20" --admin $admin_addr -y -o json  )
cw20_hash=$(echo "$cw20_i" | jq -r '.txhash' )
sleep 3;
cw20_tx=$($binary q tx $cw20_hash -o json)
cw20_addr=$(echo "$cw20_tx" | jq -r '.logs[].events[] | select(.type == "instantiate") | .attributes[] | select(.key == "_contract_address") | .value')
echo "cw20_addr: $cw20_addr"

# ############################ 3. Instantiate Mock NETA DAO ############################
echo "Instantiate Mock NETA DAO"
# proposal module info 
I_PROP_MODULE=$(cat <<EOF 
{
  "allow_revoting": true,
  "executor_addr": "$admin_addr",
  "deposit_info": {
    "deposit": "15000000",
    "refund_failed_proposals": false,
    "token": {
      "voting_module_token": {}
    }
  },
  "max_voting_period": {
    "time": 432000
  },
  "only_members_execute": true,
  "threshold": {
    "threshold_quorum": {
      "quorum": {
        "percent": "0.10"
      },
      "threshold": {
        "majority": {}
      }
    }
  }
}
EOF
)

# voting module info 
I_VOTING_MODULE=$(cat <<EOF 
{
  "token_info": {
    "existing": {
      "address": "$cw20_addr",
      "staking_contract": {
        "new": {
          "staking_code_id": $staking_module_code_id,
          "unstaking_duration": {
            "time": 7862400
          }
        }
      }
    }
  }
}
EOF
)

# # Base64 encoded msgs
binary_prop_module_msg=$(echo $I_PROP_MODULE | jq -c . | base64)
binary_voting_module_msg=$(echo $I_VOTING_MODULE | jq -c . | base64)
echo $binary_prop_module_msg
echo $binary_voting_module_msg

# cw-core instantiate msg
DAO_MSG=$(cat <<EOF 
{
    "admin": "$admin_addr",
    "automatically_add_cw20s": true,
    "automatically_add_cw721s": true,
    "description": "Neta DAO. The Community Accelerator - Funding collaboration, growth and innovation around  NETA. For more info visit https://netadao.zone/",
    "image_url": "https://github.com/netadao/organizational-docs/blob/main/assets/NetaDAO_Logo.png?raw=true",
    "name": "Neta DAO",
    "proposal_modules_instantiate_info": [
        {
            "admin": {
                "address": {"addr":"$admin_addr"}
            },
            "code_id": $proposal_module_code_id,
            "label": "DAO_Neta DAO_cw-proposal-single",
            "msg": "$binary_prop_module_msg"
        }
    ],
    "voting_module_instantiate_info": {
         "admin": {
                "address": {"addr":"$admin_addr"}
            },
        "code_id": $cw20_staked_balance_voting_code_id,
        "label": "DAO_Neta DAO_cw20-staked-balance-voting",
        "msg": "$binary_voting_module_msg"
    }
}

EOF
)
dao_response=''$binary' tx wasm i '$cw_core_code_id' "$DAO_MSG" --from test1 --gas auto --gas-adjustment 2 --gas-prices 0.05ujuno  --label="neta-dao" --admin '$admin_addr' -y -o json'
dao_res=$(eval $dao_response);
echo $dao_res

if [ -n "$dao_res" ]; then
    txhash=$(echo "$dao_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)

    dao_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "dao") | .value')
    proposal_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "prop_module") | .value')
    voting_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "voting_module") | .value')
    staking_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "staking_contract") | .value')
    echo "###########################" 
    echo "dao_address: $dao_addr"
    echo "proposal_addr: $proposal_addr"
    echo "voting_addr: $voting_addr"
    echo "staking_addr: $staking_addr"
    echo "###########################" 
else
    echo "Error: Empty response"
fi


# ####################### 4. Stake Tokens to DAO ###########################
echo "Stake Tokens to DAO"

CW20_MSG=$(cat <<EOF 
{"send":{
    "contract": "$staking_addr",
    "amount": "100",
    "msg": "eyJzdGFrZSI6e319Cg=="
}}
EOF
)

echo $CW20_MSG
stake_response='$binary tx wasm e '$cw20_addr' "$CW20_MSG" --from test1 --gas auto --gas-adjustment 2 --gas-prices 0.05ujuno  -y -o json'
stake_res=$(eval $stake_response);

if [ -n "$stake_res" ]; then
    txhash=$(echo "$stake_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

# # ########################### 5. Migrate Contract As Admin ########################
echo "Migrate Contract As Admin"
$binary tx wasm migrate $proposal_addr $proposal_code_id '{"NetaToV1":{}}' --from test1 -y -o json

########################### 6. Migrate From V1 to V2 ########################
# MIGRATE=$(cat <<EOF 
# {"deposit_info":{"amount":"15000000","denom":{"token":{"denom":{"cw20":"juno1wug8sewp6cedgkmrmvhl3lf3tulagm9hnvy8p0rppz9yjw0g4wtqwrw37d"}}},"refund_policy":"only_passed"},"extension":{},"open_proposal_submission":false}
# EOF
# )

# binary_migrate=$(echo $MIGRATE | jq -c . | base64)
# MIGRATE_MSG=$(cat <<EOF 
# {
#   "from_v1": {
#     "dao_uri": "https://daodao.zone/dao/juno1suhgf5svhu4usrurvxzlgn54ksxmn8gljarjtxqnapv8kjnp4nrsf8smqw",
#     "params": {
#       "migrator_code_id": $migrator_code_id,
#       "params": {
#         "sub_daos": [],
#         "migration_params": {
#           "migrate_stake_cw20_manager": true,
#           "proposal_params": [
#             [
#               "$proposal_addr",
#               {
#                 "close_proposal_on_execution_failure": true,
#                 "pre_propose_info": {
#                   "module_may_propose": {
#                     "info": {
#                       "admin": {
#                         "core_module": {}
#                       },
#                       "code_id": $v2_pre_propose_code_id,
#                       "label": "DAO_Neta DAO_pre-propose-DaoProposalSingle",
#                       "funds": [],
#                       "msg": "$binary_migrate"
#                     }
#                   }
#                 }
#               }
#             ]
#           ]
#         },
#         "v1_code_ids": {
#           "proposal_single": $proposal_code_id,
#           "cw4_voting": $cw4_voting_code_id,
#           "cw20_stake": $cw20_stake,
#           "cw20_staked_balances_voting": $staking_module_code_id
#         },
#         "v2_code_ids": {
#           "proposal_single": $v2_proposal_single_code_id,
#           "cw4_voting": $v2_cw4_voting_code_id,
#           "cw20_stake": $v2_cw20_stake_code_id,
#           "cw20_staked_balances_voting" $v2_cw20_staked_balances_voting_code_id: 
#         }
#       }
#     }
#   }
# }
# EOF
# )

# v1v2res=''$binary' tx wasm migrate '$dao_addr' '$v2_dao_code_id' "$MIGRATE_MSG" --from test1 --gas auto --gas-adjustment 2 --gas-prices 0.05ujuno'
# v1v2_tx=$(eval $v1v2res);
# echo $v1v2_tx