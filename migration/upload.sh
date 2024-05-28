
gas_prices=0.01ujuno
chain_id=120u-1
binary=junod

flags="--from test1 --gas-prices '$gas_prices'  --gas-adjustment 1.7 --gas auto --chain-id '$chain_id' --yes -o json"
# neta-dao contracts
for d in ./current-contracts/*.wasm; do
    echo $d;
    response_command="'$binary' tx wasm store $d $flags";
    response=$(eval $response_command);
    if [ -n "$response" ]; then
        txhash=$(echo "$response" | jq -r '.txhash')
        echo "Using txhash: $txhash"
        sleep 3;

        query_command=''$binary' q tx '$txhash' -o json'
        response=$(eval "$query_command")
        code_id=$( echo "$response" | sed -n 's/.*"key":"code_id","value":"\([^"]*\)".*/\1/p' )
        echo $code_id;
    else
        echo "Error: Empty response"
    fi
    echo "-----------------";
done

# v1-daodao
for d in ./new-contracts/*.wasm; do
    echo $d;
    response_command="'$binary' tx wasm store $d $flags";
    response=$(eval $response_command);
    if [ -n "$response" ]; then
        txhash=$(echo "$response" | jq -r '.txhash')
        echo "Using txhash: $txhash"
        sleep 3;

        query_command=''$binary' q tx '$txhash' -o json'
        response=$(eval "$query_command")
        code_id=$( echo "$response" | sed -n 's/.*"key":"code_id","value":"\([^"]*\)".*/\1/p' )
        echo $code_id;
    else
        echo "Error: Empty response"
    fi
    echo "-----------------";
done

# v2-daodao
## - proposal_single
## - cw4_voting
## - cw20_stake
## - cw20_staked_balances_voting
## - migrator_code_id
## - pre_propose_single_code_id
## - v2_dao_code_id
for d in ./v2-contracts/*.wasm; do
    echo $d;
    response_command="'$binary' tx wasm store $d $flags";
    response=$(eval $response_command);
    if [ -n "$response" ]; then
        txhash=$(echo "$response" | jq -r '.txhash')
        echo "Using txhash: $txhash"
        sleep 3;

        query_command=''$binary' q tx '$txhash' -o json'
        response=$(eval "$query_command")
        code_id=$( echo "$response" | sed -n 's/.*"key":"code_id","value":"\([^"]*\)".*/\1/p' )
        echo $code_id;
    else
        echo "Error: Empty response"
    fi
    echo "-----------------";
done