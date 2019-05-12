set -x

JSON_RPC="http://localhost:1234"

# start geth in a local container
docker container run --rm -d --name deployment-proxy-geth -p 1234:8545 -e GETH_VERBOSITY=3 keydonix/geth-clique
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
BYTECODE="6080604052348015600f57600080fd5b5060848061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063c3cafc6f14602d575b600080fd5b6033604f565b604051808260ff1660ff16815260200191505060405180910390f35b6000602a90509056fea165627a7a72305820ab7651cb86b8c1487590004c2444f26ae30077a6b96c6bc62dda37f1328539250029"
MY_CONTRACT_ADDRESS=$(curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --silent --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_call\", \"params\": [{\"from\":\"$MY_ADDRESS\",\"to\":\"$DEPLOYER_ADDRESS\", \"data\":\"0x$BYTECODE\"}, \"latest\"]}" | jq --raw-output '.result')
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_sendTransaction\", \"params\": [{\"from\":\"$MY_ADDRESS\",\"to\":\"$DEPLOYER_ADDRESS\", \"gas\":\"0xf4240\", \"data\":\"0x$BYTECODE\"}]}"

# call our contract (NOTE: MY_CONTRACT_ADDRESS is the same no matter what chain we deploy to!)
MY_CONTRACT_METHOD_SIGNATURE="c3cafc6f"
curl $JSON_RPC -X 'POST' -H 'Content-Type: application/json' --data "{\"jsonrpc\":\"2.0\", \"id\":1, \"method\": \"eth_call\", \"params\": [{\"to\":\"$MY_CONTRACT_ADDRESS\", \"data\":\"0x$MY_CONTRACT_METHOD_SIGNATURE\"}, \"latest\"]}"
# expected result is 0x000000000000000000000000000000000000000000000000000000000000002a (hex encoded 42)

# shutdown Parity
docker container stop deployment-proxy-geth
