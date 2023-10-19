// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from '@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';
import {LinkTokenInterface} from '@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol';

contract Receiver is CCIPReceiver {
	address router;
	address link;

	address public latestSender;
	string public latestMessage;

	event ReceivedMessage(string message);

	constructor(address _router, address _link) CCIPReceiver(_router) {
		link = _link;
		router = _router;

		LinkTokenInterface(_link).approve(router, type(uint256).max);
	}

	function _ccipReceive(
		Client.Any2EVMMessage memory message
	) internal override {
		latestSender = abi.decode(message.sender, (address));
		latestMessage = abi.decode(message.data, (string));

		emit ReceivedMessage(latestMessage);
	}
}
