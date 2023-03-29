object "Proxy" {
	// deployment code
	code {
		let size := datasize("runtime")
		datacopy(0, dataoffset("runtime"), size)
		return(0, size)
	}
	object "runtime" {
		// deployed code
		code {
			calldatacopy(0, 0, calldatasize())
			let hash := keccak256(0, calldatasize())
			let nonce := sload(hash)
			sstore(hash, add(nonce, 1))
			let result := create2(callvalue(), 0, calldatasize(), nonce)
			if iszero(result) { revert(0, 0) }
			mstore(0, result)
			return(12, 20)
		}
	}
}
