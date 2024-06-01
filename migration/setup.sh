# Workflow 
admin_key=test1
admin_addr=juno1dze67jm4ea0tz04zvw5p5vyjf4m3wcvd958qpa
binary=junod
tx_flag='--from '$admin_key' --gas auto --gas-adjustment 2 --gas-prices 0.05ujuno -y -o json '

################## 1. Store All Contracts ##################
### run: sh upload.sh
## Old NetaDAO Contracts
cw_core_code_id=1
cw_proposal_single_code_id=2
cw20_stake_code_id=3
cw20_staked_balance_voting_code_id=4
cw20_code_id=5
cw4_voting=6
## Custom Migration V1 Contracts
compatible_proposal_code_id=7
## New V2 Contracts
v2_cw20_stake_code_id=8
v2_dao_code_id=9
v2_migrator_code_id=10
v2_pre_propose_code_id=11
v2_proposal_single_code_id=12
v2_cw20_staked_balances_voting_code_id=13
v2_cw4_voting_code_id=14


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
  "allow_revoting": false,
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
          "staking_code_id": $cw20_stake_code_id,
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
echo $I_PROP_MODULE

# base64 encoded msgs
binary_prop_module_msg=$(echo $I_PROP_MODULE | jq -c . | base64)
binary_voting_module_msg=$(echo $I_VOTING_MODULE | jq -c . | base64)
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
              "core_contract":{}
            },
            "code_id": $cw_proposal_single_code_id,
            "label": "DAO_Neta DAO_cw-proposal-single",
            "msg": "$binary_prop_module_msg"
        }
    ],
    "voting_module_instantiate_info": {
         "admin": {
            "core_contract":{}
            },
        "code_id": $cw20_staked_balance_voting_code_id,
        "label": "DAO_Neta DAO_cw20-staked-balance-voting",
        "msg": "$binary_voting_module_msg"
    }
}

EOF
)
dao_response=''$binary' tx wasm i '$cw_core_code_id' "$DAO_MSG"  '$tx_flag' --label="neta-dao" --admin '$admin_addr' -y -o json'
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
    "amount": "15000000",
    "msg": "eyJzdGFrZSI6e319Cg=="
}}
EOF
)

echo $CW20_MSG
stake_response='$binary tx wasm e '$cw20_addr' "$CW20_MSG" '$tx_flag''
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

# # ########################### 5.b Migrate Contract As Proposal ########################
echo "Setup Allowance Msg"
ALLOWANCE_MSG=$(cat <<EOF
{"increase_allowance":{"spender":"$proposal_addr","amount":"1500000000"}}
EOF
)
echo $ALLOWANCE_MSG
allowance_response='$binary tx wasm e $cw20_addr "$ALLOWANCE_MSG" '$tx_flag''
allowance_res=$(eval $allowance_response);
if [ -n "$allowance_res" ]; then
    txhash=$(echo "$allowance_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi


echo "Migrate Contract As Proposal"
VOTING_MIGRATE_MSG=$(cat <<EOF 
{"NetaToV1":{}}
EOF
)

binary_migrate_msg=$(echo $VOTING_MIGRATE_MSG | jq -c . | base64)
PROP_MSG=$(cat <<EOF 
{
  "propose":{
    "title":"test v1-v2",
    "description":"migrate proposal",
    "msgs": [
      {
        "wasm": {
          "migrate": {
            "contract_addr": "$proposal_addr",
            "msg": "$binary_migrate_msg",
            "new_code_id": $compatible_proposal_code_id
          }
        }
      }
    ]
  }
}
EOF
)
echo "Create Proposal"
migrate_proposal_response='$binary tx wasm e $proposal_addr "$PROP_MSG" '$tx_flag''
migrate_prop_res=$(eval $migrate_proposal_response);
if [ -n "$migrate_prop_res" ]; then
    txhash=$(echo "$migrate_prop_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Vote On Proposal"
VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":1,"vote": "yes"}}
EOF
)
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi
echo "Execute Proposal"
EXECUTE_MSG=$(cat <<EOF 
{"execute":{"proposal_id":1}}
EOF
)
execute_response='$binary tx wasm e $proposal_addr "$EXECUTE_MSG" '$tx_flag''
execute_res=$(eval $execute_response);
if [ -n "$execute_res" ]; then
    txhash=$(echo "$execute_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

########################## 6. Migrate From V1 to V2 ########################
MIGRATE=$(cat <<EOF 
{"deposit_info":{"amount":"15000000","denom":{"token":{"denom":{"cw20":"$cw20_addr"}}},"refund_policy":"only_passed"},"extension":{},"open_proposal_submission":false}
EOF
)
binary_migrate=$(echo $MIGRATE | jq -c . | base64)

MIGRATE_MSG=$(cat <<EOF 
{ 
  "from_v1": {
    "dao_uri":"https://daodao.zone/dao",
    "params": {
      "migrator_code_id": $v2_migrator_code_id, 
      "params":{
        "sub_daos": [],
        "migration_params": {
          "migrate_stake_cw20_manager": true,
          "proposal_params": [
            [
              "$proposal_addr",
              {
                "close_proposal_on_execution_failure": true,
                "pre_propose_info": {
                  "module_may_propose":{
                    "info": {
                     "admin": {
                        "core_module":{}
                      },
                      "code_id": $v2_pre_propose_code_id,
                      "label": "DAO_Neta DAO_pre-propose-DaoProposalSingle",
                      "funds": [],
                      "msg": "$binary_migrate"
                    }
                  }
                  
                }
              }
            ]
          ]
        },
        "v1_code_ids": {
          "proposal_single": $compatible_proposal_code_id,
          "cw4_voting": $cw4_voting,
          "cw20_stake": $cw20_stake_code_id,
          "cw20_staked_balances_voting": $cw20_staked_balance_voting_code_id
        },
         "v2_code_ids": {
           "proposal_single": $v2_proposal_single_code_id,
           "cw4_voting": $v2_cw4_voting_code_id,
           "cw20_stake": $v2_cw20_stake_code_id,
           "cw20_staked_balances_voting": $v2_cw20_staked_balances_voting_code_id
         }
      }}}}
EOF
)

v1v2res='$binary tx wasm migrate $dao_addr $v2_dao_code_id "$MIGRATE_MSG" '$tx_flag''
v1v2_tx=$(eval $v1v2res);
if [ -n "$v1v2_tx" ]; then
    txhash=$(echo "$v1v2_tx" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished migration with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

########################## 7.Test Migration Worked ########################
DUMP_STATE=$(cat <<EOF 
{"dump_state":{}}
EOF
)

CREATION_POLICY=$(cat <<EOF 
{"proposal_creation_policy":{}}
EOF
)
echo "Test Migration Worked"
confirm_migrate_query='$binary q wasm contract-state smart $dao_addr "$DUMP_STATE" -o json'
migrate_res=$(eval $confirm_migrate_query);
version=$(echo $migrate_res | jq -r '.data.version.version')
echo 'DAO contract current version: '$txhash''

prop_query='$binary q wasm contract-state smart $proposal_addr "$CREATION_POLICY" -o json'
prop_query_res=$(eval $prop_query);
pre_propose_addr=$(echo $prop_query_res | jq -r '.data.module.addr')
echo 'pre_propose_addr: '$pre_propose_addr''

echo "Fund DAO"
fund_dao='$binary tx bank send $admin_addr $dao_addr 100ujuno --gas auto --gas-adjustment 2 --gas-prices 0.05ujuno -y -o json'
fund_res=$(eval $fund_dao);
fund_txhash=$(echo "$fund_res" | jq -r '.txhash')
echo $fund_txhash
sleep 3;

echo "Confirm Some Balance"
confirm_empty_balance_query='$binary q bank balances $dao_addr -o json'
bal_query1=$(eval $confirm_empty_balance_query);
echo $bal_query1

echo "Setup Allowance Msg"
NEW_ALLOWANCE=$(cat <<EOF
{"increase_allowance":{"spender":"$pre_propose_addr","amount":"1500000000"}}
EOF
)
echo $NEW_ALLOWANCE
allowance_response='$binary tx wasm e $cw20_addr "$NEW_ALLOWANCE" '$tx_flag''
allowance_res=$(eval $allowance_response);
if [ -n "$allowance_res" ]; then
    txhash=$(echo "$allowance_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi



# ########################## 7a. Create V2 Proposal ########################
NEW_MSG=$(cat <<EOF 
{
  "propose": {
    "msg": {
      "propose": {
        "title": "test v2 prop",
        "description": "migrate proposal",
        "msgs": [
          {
            "bank": {
              "send": {
                "from_address": "$dao_addr",
                "to_address": "$admin_addr",
                "amount": [
                  {
                    "denom": "ujuno",
                    "amount": "100"
                  }
                ]
              }
            }
          }
        ]
      }
    }
  }
}
EOF
)

echo "Create Proposal"
second_prop='$binary tx wasm e $pre_propose_addr "$NEW_MSG" '$tx_flag''
second_prop_res=$(eval $second_prop);
if [ -n "$migrate_prop_res" ]; then
    txhash=$(echo "$migrate_prop_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Vote On Proposal"
VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":2,"vote": "yes"}}
EOF
)
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi
echo "Execute Proposal"
EXECUTE_MSG=$(cat <<EOF 
{"execute":{"proposal_id":2}}
EOF
)
execute_response='$binary tx wasm e $proposal_addr "$EXECUTE_MSG" '$tx_flag''
execute_res=$(eval $execute_response);
if [ -n "$execute_res" ]; then
    txhash=$(echo "$execute_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 3;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Confirm Empty Balance"
confirm_empty_balance_query='$binary q bank balances $dao_addr -o json'
bal_query=$(eval $confirm_empty_balance_query);
echo $bal_query