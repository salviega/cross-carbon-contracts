// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICommunicator {
	function send(
		address receiver,
		string memory messageContent,
		uint64 destinationChainSelector
	) external;
}
