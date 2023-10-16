// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from '@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol';

interface IERC20Extended is IERC20 {
	function decimals() external view returns (uint8);
}
