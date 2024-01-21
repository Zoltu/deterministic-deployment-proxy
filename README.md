# Deterministic Deployment Proxy
This is a proxy contract that can be deployed to any chain at the same address, and can then in turn deploy any contract at a deterministic location using CREATE2.  To use, first deploy the contract using the one-time-account transaction specified in `output/deployment.json` (or grab last known good from bottom of readme), then submit a transaction `to` the address specified in `output/deployment.json` (or grab last known good from bottom of readme) and supply your init code as the `data`.  This is just like deploying a transaction normally, except change the `to` field from `null`.

## Usage
```bash
npm install
npm run build
./scripts/test.sh
```

### Details
See `scripts/test.sh` (commented).  Change `JSON_RPC` environment variable to the chain of your choice (requires an unlocked wallet with ETH).  Notice that the script works against _any_ chain!  If the chain already has the deployer contract deployed to it, then you can just comment out the deployment steps (line 20 and 23) and everything else will still function as normal.  If you have already deployed your contract with it to the chain you are pointing at, the script will fail because your contract already exists at its address.

## Explanation
This repository contains a simple contract that can deploy other contracts with a deterministic address on any chain using CREATE2.  The CREATE2 call will deploy a contract (like CREATE opcode) but instead of the address being `keccak256(rlp([deployer_address, nonce]))` it instead uses the hash of the contract's bytecode and a salt.  This means that a given deployer address will deploy the same code to the same address no matter _when_ or _where_ they issue the deployment.  The deployer is deployed with a one-time-use-account, so no matter what chain the deployer is on, its address will always be the same.  This means the only variables in determining the address of your contract are its bytecode hash and the provided salt.

Between the use of CREATE2 opcode and the one-time-use-account for the deployer, we can ensure that a given contract will exist at the _exact_ same address on every chain, but without having to use the same gas pricing or limits every time.

----

## Latest Outputs

**Note:** as of last readme update; don't trust these to be latest!

Information below is for the proxy at commit `5511264edcaaa4b9eb4028e228c41010fed9c04e`.

It is known to have been deployed to: [Ethereum main-net](https://etherscan.io/address/0x7A0D94F55792C434d74a40883C6ed8545E406D12), [Ropsten test-net](https://ropsten.etherscan.io/address/0x7A0D94F55792C434d74a40883C6ed8545E406D12), [Görli test-net](https://goerli.etherscan.io/address/0x7A0D94F55792C434d74a40883C6ed8545E406D12), [Sepolia test-net](https://sepolia.etherscan.io/address/0x7A0D94F55792C434d74a40883C6ed8545E406D12)

### Proxy Address
```
0x7A0D94F55792C434d74a40883C6ed8545E406D12
```

### Deployment Transaction
```
0xf87e8085174876e800830186a08080ad601f80600e600039806000f350fe60003681823780368234f58015156014578182fd5b80825250506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222
```

### Deployment Signer Address
```
0x4c8D290a1B368ac4728d83a9e8321fC3af2b39b1
```

### Deployment Gas Price
```
100 nanoeth (gwei)
```

### Deployment Gas Limit
```
100000
```

**Note:** The actual gas used is 62095, but that can change if the cost of opcodes changes.  To avoid having to move the proxy to a different address, we opted to give excess gas.  Given the gas price, this may result in notable expenses, but since this only needs to be deployed once per chain that is acceptable.
