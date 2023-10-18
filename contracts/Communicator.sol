// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';
import {LinkTokenInterface} from '@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol';
import {CCIPReceiver} from '@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract Communicator is Ownable, CCIPReceiver {
	address public s_lastSender;
	string public s_lastMessage;

	address router;
	address link;

	event ReceivedMessage(string message);

	constructor(
		address _router,
		address _link
	) CCIPReceiver(_router) Ownable(msg.sender) {
		router = _router;
		link = _link;

		LinkTokenInterface(link).approve(router, type(uint256).max);
	}

	function send(
		address receiver,
		string memory message, // Renaming the parameter to avoid shadowing
		uint64 destinationChainSelector
	) external onlyOwner {
		Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
			receiver: abi.encode(receiver),
			data: abi.encode(message),
			tokenAmounts: new Client.EVMTokenAmount[](0),
			extraArgs: '',
			feeToken: link
		});

		IRouterClient(router).ccipSend(destinationChainSelector, message);
		emit ReceivedMessage(abi.decode(message.data, (string)));
	}

	function _ccipReceive(
		Client.Any2EVMMessage memory message
	) internal override {
		s_lastSender = abi.decode(message.sender, (address));
		s_lastMessage = abi.decode(message.data, (string));

		emit ReceivedMessage(s_lastMessage);
	}
}
