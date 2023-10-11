// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * Network: Mumbai
 * name: TCO2Faucet
 * Address: 0x996b39698CF96A70B7a7005B5d1924a66C5E8f0e
 **/

interface ITCO2Faucet {
	function withdraw(address _erc20Address, uint256 _amount) external;
}
