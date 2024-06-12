# Workflow 
admin_key= # main key for tx
admin_addr=  
bid_key= # secondary key for complexity in proposers
bid_addr=
binary=junod 
denom=ujunox # primary token
tx_flag="--from $admin_key --gas auto --gas-adjustment 2 --gas-prices 0.05$denom -y -o json" # transaction flags for admin_key
tx_flag2="--from $bid_key --gas auto --gas-adjustment 2 --gas-prices 0.05$denom -y -o json"  # transaction flags for bid_key

################## Store All Contracts ##################
### First,  run `sh upload.sh` to store all of the contracts required.
### Then, populate the correct ids for this scripts contract variables.
## Old NetaDAO Contracts
cw_core_code_id=4509
cw_proposal_single_code_id=4510
cw20_stake_code_id=4511
cw20_staked_balance_voting_code_id=4512
cw20_code_id=4513
cw4_voting=4514
## Custom Migration V1 Contracts
compatible_proposal_code_id=4515
## New V2 Contracts
v2_cw20_stake_code_id=4516
v2_dao_code_id=4517
v2_migrator_code_id=4518
v2_pre_propose_code_id=4519
v2_proposal_single_code_id=4520
v2_cw20_staked_balances_voting_code_id=4521
v2_cw4_voting_code_id=4522

################## 1.Fund 2nd account ##################
BAL_MSG=$(cat <<EOF 
{"balance":{"address":"$admin_addr"}}
EOF
)
BAL_MSG2=$(cat <<EOF 
{"balance":{"address":"$bid_addr"}}
EOF
)

# echo "Fund Bid"
# fund_dao='$binary tx bank send $admin_addr $bid_addr 10000000'$denom' '$tx_flag''
# fund_res=$(eval $fund_dao);
# fund_txhash=$(echo "$fund_res" | jq -r '.txhash')
# echo $fund_txhash
# sleep 6;
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
        },
        {
            "address": "$bid_addr",
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
echo " ################## Instantiate Mock NETA CW20 ##################"
cw20_i=$($binary tx wasm i $cw20_code_id "$MSG" $tx_flag --label="cw20" --admin $admin_addr  )
echo "$cw20_i"
cw20_hash=$(echo "$cw20_i" | jq -r '.txhash')
sleep 6;
cw20_tx=$($binary q tx $cw20_hash -o json)
cw20_addr=$(echo "$cw20_tx" | jq -r '.logs[].events[] | select(.type == "instantiate") | .attributes[] | select(.key == "_contract_address") | .value')
echo "cw20_addr: $cw20_addr"

echo "Confirm Admin Balance"
bal_q='$binary q wasm contract-state smart $cw20_addr "$BAL_MSG" -o json'
bal_res=$(eval $bal_q);
echo $bal_res;

echo "Confirm Bid Balance"
bal_q2='$binary q wasm contract-state smart $cw20_addr "$BAL_MSG2" -o json'
bal_res2=$(eval $bal_q2);
echo $bal_res2;


# ############################ 4. Instantiate Mock NETA DAO ############################
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
echo "################ 4. Instantiate Mock NETA DAO ############"
dao_response=''$binary' tx wasm i '$cw_core_code_id' "$DAO_MSG"  '$tx_flag' --label="neta-dao" --admin '$admin_addr' -y -o json'
dao_res=$(eval $dao_response);
echo $dao_res

if [ -n "$dao_res" ]; then
    txhash=$(echo "$dao_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)

    dao_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "dao") | .value')
    proposal_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "prop_module") | .value')
    voting_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "voting_module") | .value')
    staking_addr=$(echo "$tx_response" | jq -r '.logs[].events[] | select(.type == "wasm") | .attributes[] | select(.key == "staking_contract") | .value')
    echo "" 
    echo "" 
    echo "" 
    echo "#################################################################################" 
    echo "dao_address: $dao_addr"
    echo "proposal_addr: $proposal_addr"
    echo "voting_addr: $voting_addr"
    echo "staking_addr: $staking_addr"
    echo "#################################################################################" 
    echo "" 
    echo "" 
    echo ""
    echo "" 
    echo ""
else
    echo "Error: Empty response"
fi

# ####################### 5. Stake Tokens to DAO ###########################
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
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Stake Tokens to DAO As Bid"

CW20_MSG=$(cat <<EOF 
{"send":{
    "contract": "$staking_addr",
    "amount": "15000000",
    "msg": "eyJzdGFrZSI6e319Cg=="
}}
EOF
)

echo $CW20_MSG
stake_response2='$binary tx wasm e '$cw20_addr' "$CW20_MSG" '$tx_flag2''
stake_res2=$(eval $stake_response2);

if [ -n "$stake_res2" ]; then
    txhash=$(echo "$stake_res2" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

# # ########################### 6 Migrate Contract As Proposal ########################
echo "Setup Allowance Msg"
ALLOWANCE_MSG=$(cat <<EOF
{"increase_allowance":{"spender":"$proposal_addr","amount":"1500000000"}}
EOF
)
echo $ALLOWANCE_MSG
allowance_response='$binary tx wasm e $cw20_addr "$ALLOWANCE_MSG" '$tx_flag2''
allowance_res=$(eval $allowance_response);
if [ -n "$allowance_res" ]; then
    txhash=$(echo "$allowance_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
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
    "title":"test neta -> v1 ",
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
echo "Create Neta -> V1 Proposal"
migrate_proposal_response='$binary tx wasm e $proposal_addr "$PROP_MSG" '$tx_flag2''
migrate_prop_res=$(eval $migrate_proposal_response);
if [ -n "$migrate_prop_res" ]; then
    txhash=$(echo "$migrate_prop_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":1,"vote": "yes"}}
EOF
)
echo "############ Vote On Neta -> V1 Proposal as Admin ##################"
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi
echo "############  Vote On Neta -> V1 Proposal as Bid ##################"
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag2''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi
############ 7. Execute Neta -> V1 Migration ##################
echo "############ Execute Neta -> V1 Migration ##################"
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
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

#################### 7.a Check DAO  ####################
echo "#################### 7.a Check DAO  ####################"
Q_MSG_V1=$(cat <<EOF 
{"next_proposal_id":{}}
EOF
)

q_count='$binary q wasm contract-state smart $proposal_addr "$Q_MSG_V1"'
q_count_res=$(eval $q_count);
echo $q_count_res;

########################## 8. Migrate From V1 to V2 ########################
echo "############ Migrate V1 -> V2 As Admin ##################"
MIGRATE=$(cat <<EOF 
{"deposit_info":{"amount":"15000000","denom":{"token":{"denom":{"cw20":"$cw20_addr"}}},"refund_policy":"only_passed"},"extension":{},"open_proposal_submission":false}
EOF
)
binary_migrate=$(echo $MIGRATE | jq -c . | base64)

MIGRATE_MSG=$(cat <<EOF 
{ 
  "from_v1": {
    "dao_uri":"https://daodao.zone/dao/",
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
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

########################## 9.Test Migration Worked ########################
DUMP_STATE=$(cat <<EOF 
{"dump_state":{}}
EOF
)

CREATION_POLICY=$(cat <<EOF 
{"proposal_creation_policy":{}}
EOF
)
echo "Test V1 -> V2 Migration Worked"
confirm_migrate_query='$binary q wasm contract-state smart $dao_addr "$DUMP_STATE" -o json'
migrate_res=$(eval $confirm_migrate_query);
version=$(echo $migrate_res | jq -r '.data.version.version')
echo 'DAO contract current version: '$version''

prop_query='$binary q wasm contract-state smart $proposal_addr "$CREATION_POLICY" -o json'
prop_query_res=$(eval $prop_query);
pre_propose_addr=$(echo $prop_query_res | jq -r '.data.module.addr')
echo 'pre_propose_addr: '$pre_propose_addr''

echo "Fund DAO"
fund_dao='$binary tx bank send $admin_addr $dao_addr 200'$denom' '$tx_flag''
fund_res=$(eval $fund_dao);
fund_txhash=$(echo "$fund_res" | jq -r '.txhash')
echo $fund_txhash
sleep 6;

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
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi



# ########################## 10a. Create V2 Proposal ########################
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
                    "denom": "ujunox",
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
if [ -n "$second_prop_res" ]; then
    txhash=$(echo "$second_prop_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Confirm Deposit is Returned"
bal_q='$binary q wasm contract-state smart $cw20_addr "$BAL_MSG" -o json'
bal_res=$(eval $bal_q);
echo $bal_res;


echo "Vote On Proposal as Admin"
VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":2,"vote": "yes"}}
EOF
)
sleep 2;
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Vote On v2 as Bidder"
VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":2,"vote": "yes"}}
EOF
)
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag2''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
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
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Confirm Empty Balance"
confirm_empty_balance_query='$binary q bank balances $dao_addr -o json'
bal_query1=$(eval $confirm_empty_balance_query);
echo $bal_query1

echo "Confirm Deposit is Returned"
bal_q='$binary q wasm contract-state smart $cw20_addr "$BAL_MSG" -o json'
bal_res=$(eval $bal_q);
echo $bal_res;


echo "Confirm Next Propsal Id is 3"
q_count='$binary q wasm contract-state smart $proposal_addr "$Q_MSG_V1"'
q_count_res=$(eval $q_count);
echo $q_count_res;


echo "Create Another Proposal "
third_prop='$binary tx wasm e $pre_propose_addr "$NEW_MSG" '$tx_flag''
third_prop_res=$(eval $third_prop);
if [ -n "$third_prop_res" ]; then
    txhash=$(echo "$third_prop_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Confirm Deposit is Returned"
bal_q='$binary q wasm contract-state smart $cw20_addr "$BAL_MSG" -o json'
bal_res=$(eval $bal_q);
echo $bal_res;


echo "Vote On Proposal as Admin"
VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":3,"vote": "yes"}}
EOF
)
sleep 2;
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Vote On Proposal as Bidder"
VOTE_MSG=$(cat <<EOF 
{"vote":{"proposal_id":3,"vote": "yes"}}
EOF
)
vote_msg_response='$binary tx wasm e $proposal_addr "$VOTE_MSG" '$tx_flag2''
vote_res=$(eval $vote_msg_response);
if [ -n "$vote_res" ]; then
    txhash=$(echo "$vote_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Execute Proposal"
EXECUTE_MSG=$(cat <<EOF 
{"execute":{"proposal_id":3}}
EOF
)
execute_response='$binary tx wasm e $proposal_addr "$EXECUTE_MSG" '$tx_flag''
execute_res=$(eval $execute_response);
if [ -n "$execute_res" ]; then
    txhash=$(echo "$execute_res" | jq -r '.txhash')
    echo 'waiting for tx to process'
    echo 'finished with txhash: '$txhash''
    sleep 6;
    tx_response=$($binary q tx $txhash -o json)
    # echo 'finished with tx_response: '$tx_response''
else
    echo "Error: Empty response"
fi

echo "Confirm Empty Balance"
confirm_empty_balance_query='$binary q bank balances $dao_addr -o json'
bal_query1=$(eval $confirm_empty_balance_query);
echo $bal_query1

echo "Confirm Next Propsal Id is 4"
q_count='$binary q wasm contract-state smart $proposal_addr "$Q_MSG_V1"'
q_count_res=$(eval $q_count);
echo $q_count_res;