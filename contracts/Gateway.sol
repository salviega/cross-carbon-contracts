// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';
import {OwnerIsCreator} from '@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';
import {LinkTokenInterface} from '@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol';

import '@openzeppelin/contracts/utils/Strings.sol';

import './interfaces/IERC20Extended.sol';
import './interfaces/IPUSHCommInterface.sol';

contract Gateway is OwnerIsCreator {
	using Strings for address;
	using Strings for string;
	using Strings for uint;

	IRouterClient router;
	LinkTokenInterface linkToken;

	address public EPNS_COMM_ADDRESS;

	mapping(uint64 => bool) public whitelistedChains;

	error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
	error NothingToWithdraw();
	error FailedToWithdrawEth(address owner, address target, uint256 value);
	error DestinationChainNotWhitelisted(uint64 destinationChainSelector);

	modifier onlyWhitelistedChain(uint64 _destinationChainSelector) {
		if (!whitelistedChains[_destinationChainSelector])
			revert DestinationChainNotWhitelisted(_destinationChainSelector);
		_;
	}

	event TokensTransferred(
		bytes32 indexed messageId,
		uint64 indexed destinationChainSelector,
		address receiver,
		address token,
		uint256 tokenAmount,
		address feeToken,
		uint256 fees
	);

	constructor(address _router, address _link, address _EPNS_COMM_ADDRESS) {
		router = IRouterClient(_router);
		linkToken = LinkTokenInterface(_link);

		EPNS_COMM_ADDRESS = _EPNS_COMM_ADDRESS;
	}

	receive() external payable {}

	function whitelistChain(uint64 _destinationChainSelector) external onlyOwner {
		whitelistedChains[_destinationChainSelector] = true;
	}

	function denylistChain(uint64 _destinationChainSelector) external onlyOwner {
		whitelistedChains[_destinationChainSelector] = false;
	}

	function transferTokens(
		uint64 _destinationChainSelector,
		address _receiver,
		address _token,
		uint256 _amount
	)
		external
		onlyOwner
		onlyWhitelistedChain(_destinationChainSelector)
		returns (bytes32 messageId)
	{
		Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](
			1
		);
		Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
			token: _token,
			amount: _amount
		});
		tokenAmounts[0] = tokenAmount;

		// Build the CCIP Message
		Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
			receiver: abi.encode(_receiver),
			data: '',
			tokenAmounts: tokenAmounts,
			extraArgs: Client._argsToBytes(
				Client.EVMExtraArgsV1({gasLimit: 0, strict: false})
			),
			feeToken: address(linkToken)
		});

		// CCIP Fees Management
		uint256 fees = router.getFee(_destinationChainSelector, message);

		if (fees > linkToken.balanceOf(address(this)))
			revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);

		linkToken.approve(address(router), fees);

		// Approve Router to spend CCIP-BnM tokens we send
		IERC20(_token).approve(address(router), _amount);

		// Send CCIP Message
		messageId = router.ccipSend(_destinationChainSelector, message);

		// if (EPNS_COMM_ADDRESS != address(0)) {
		// 	IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
		// 		0xaA7880DB88D8e051428b5204817e58D8327340De, // from channel
		// 		msg.sender,
		// 		bytes(
		// 			string(
		// 				abi.encodePacked(
		// 					'0',
		// 					'+',
		// 					'3',
		// 					'+',
		// 					'Congrats!',
		// 					'+',
		// 					'You just sent ',
		// 					(_amount / (10 ** uint(IERC20Extended(_token).decimals())))
		// 						.toString(),
		// 					' CARBON! to Optimism'
		// 				)
		// 			)
		// 		)
		// 	);
		// }

		emit TokensTransferred(
			messageId,
			_destinationChainSelector,
			_receiver,
			_token,
			_amount,
			address(linkToken),
			fees
		);
	}

	function withdrawToken(
		address _beneficiary,
		address _token
	) public onlyOwner {
		uint256 amount = IERC20(_token).balanceOf(address(this));

		if (amount == 0) revert NothingToWithdraw();

		IERC20(_token).transfer(_beneficiary, amount);
	}
}
