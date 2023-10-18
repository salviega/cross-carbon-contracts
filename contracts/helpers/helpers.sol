// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Helpers {
	function equal(
		string memory _a,
		string memory _b
	) internal pure returns (bool) {
		return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
	}

	function _validateAddresses(
		address _TCO2Faucet,
		address _TCO2Token,
		address _EPNS_COMM_ADDRESS
	) internal pure returns (bool) {
		return (_TCO2Faucet != address(0) &&
			_TCO2Token != address(0) &&
			_EPNS_COMM_ADDRESS != address(0));
	}
}
