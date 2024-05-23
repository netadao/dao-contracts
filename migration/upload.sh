
gas_prices=0.01ujuno
chain_id=120u-1
binary=junod

flags="--from test1 --gas-prices '$gas_prices'  --gas-adjustment 1.7 --gas auto --chain-id '$chain_id' --yes -o json"
for d in ./old-contracts/*.wasm; do
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