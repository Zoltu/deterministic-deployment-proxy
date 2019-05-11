pragma solidity 0.5.8;

contract DeterministicDeploymentProxy {
	function deploy(bytes calldata _data, uint256 _salt) external payable returns (address) {
		uint256 _value = msg.value;
		bytes memory _data2 = _data;
		address _new_contract;
		/* solium-disable-next-line */
		assembly {
			_new_contract := create2(_value, add(_data2, 32), mload(_data2), _salt)
		}
		require(_new_contract != address(0), "Contract creation failed.");
		return _new_contract;
	}
}
