// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * Network: Mumbai
 * name: TCO2Token
 * Address: 0xa5831eb637dff307395b5183c86B04c69C518681
 **/

interface ITCO2Token is IERC20 {
	function retire(uint256 amount) external;
}
