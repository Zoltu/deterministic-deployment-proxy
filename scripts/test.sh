set -x

JSON_RPC="http://localhost:1234"

# start geth in a local container
GETH_CONTAINER_ID=$(docker container run --rm -d -p 1234:8545 -e GETH_VERBOSITY=3 keydonix/geth-clique)
# wait for geth to become responsive
until $(curl --output /dev/null --silent --fail $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"net_version\", \"params\": []}"); do sleep 1; done

# extract the variables we need from json output
MY_ADDRESS="0x913dA4198E6bE1D5f5E4a40D0667f70C0B5430Eb"
ONE_TIME_SIGNER_ADDRESS="0x$(cat output/deployment.json | jq --raw-output '.signerAddress')"
GAS_COST="0x$(printf '%x' $(($(cat output/deployment.json | jq --raw-output '.gasPrice') * $(cat output/deployment.json | jq --raw-output '.gasLimit'))))"
TRANSACTION="0x$(cat output/deployment.json | jq --raw-output '.transaction')"
DEPLOYER_ADDRESS="0x$(cat output/deployment.json | jq --raw-output '.address')"

# send gas money to signer
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendTransaction\", \"params\": [{\"from\":\"$MY_ADDRESS\",\"to\":\"$ONE_TIME_SIGNER_ADDRESS\",\"value\":\"$GAS_COST\"}]}"

# deploy the deployer contract
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"$TRANSACTION\"]}"

# deploy our contract
# contract: pragma solidity 0.5.8; contract Apple {function banana() external pure returns (uint8) {return 42;}}
DEPLOY_SIGNATURE="9c4ae2d0"
BYTECODE_OFFSET="0000000000000000000000000000000000000000000000000000000000000040"
SALT="0000000000000000000000000000000000000000000000000000000000000000"
BYTECODE_LENGTH="0000000000000000000000000000000000000000000000000000000000000098"
BYTECODE="6080604052348015600f57600080fd5b50607a8061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063c3cafc6f14602d575b600080fd5b60336049565b6040805160ff9092168252519081900360200190f35b602a9056fea165627a7a7230582061b42c10c5aed258685366454ca535be5306e982bf70d72569122494bc53deb60029"
PADDING="0000000000000000"
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendTransaction\", \"params\": [{\"from\":\"$MY_ADDRESS\",\"to\":\"$DEPLOYER_ADDRESS\", \"data\":\"0x$DEPLOY_SIGNATURE$BYTECODE_OFFSET$SALT$BYTECODE_LENGTH$BYTECODE$PADDING\"}]}"

# call our contract (we know the address, no matter what chain we ran this script against!)
MY_CONTRACT_ADDRESS="0x8bb88a8d94804d59f8c2fb06d6605e288382e24f"
MY_CONTRACT_METHOD_SIGNATURE="c3cafc6f"
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_call\", \"params\": [{\"to\":\"$MY_CONTRACT_ADDRESS\", \"data\":\"0x$MY_CONTRACT_METHOD_SIGNATURE\"}, \"latest\"]}"
# expected result is 0x000000000000000000000000000000000000000000000000000000000000002a (hex encoded 42)

# shutdown Parity
docker container stop $GETH_CONTAINER_ID
