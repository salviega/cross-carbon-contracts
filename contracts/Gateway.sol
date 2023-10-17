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

	event TokensTransferred(
		bytes32 indexed messageId,
		uint64 indexed destinationChainSelector,
		address receiver,
		address token,
		uint256 tokenAmount,
		address feeToken,
		uint256 fees
	);

	error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
	error NothingToWithdraw();
	error FailedToWithdrawEth(address owner, address target, uint256 value);
	error DestinationChainNotWhitelisted(uint64 destinationChainSelector);

	constructor(address _router, address _link, address _EPNS_COMM_ADDRESS) {
		router = IRouterClient(_router);
		linkToken = LinkTokenInterface(_link);

		EPNS_COMM_ADDRESS = _EPNS_COMM_ADDRESS;
	}

	modifier onlyWhitelistedChain(uint64 _destinationChainSelector) {
		if (!whitelistedChains[_destinationChainSelector])
			revert DestinationChainNotWhitelisted(_destinationChainSelector);
		_;
	}

	receive() external payable {}

	function whitelistChain(uint64 _destinationChainSelector) external onlyOwner {
		whitelistedChains[_destinationChainSelector] = true;
	}

	function denylistChain(uint64 _destinationChainSelector) external onlyOwner {
		whitelistedChains[_destinationChainSelector] = false;
	}

	/// @notice Transfer tokens to receiver on the destination chain.
	/// @notice pay in LINK.
	/// @notice the token must be in the list of supported tokens.
	/// @notice This function can only be called by the owner.
	/// @dev Assumes your contract has sufficient LINK tokens to pay for the fees.
	/// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
	/// @param _receiver The address of the recipient on the destination blockchain.
	/// @param _token token address.
	/// @param _amount token amount.
	/// @return messageId The ID of the message that was sent.
	function transferTokensPayLINK(
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
		Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
			_receiver,
			_token,
			_amount,
			address(linkToken)
		);

		uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

		if (fees > linkToken.balanceOf(address(this)))
			revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);

		linkToken.approve(address(router), fees);
		IERC20(_token).approve(address(router), _amount);

		messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

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

		return messageId;
	}

	/// @notice Transfer tokens to receiver on the destination chain.
	/// @notice Pay in native gas such as ETH on Ethereum or MATIC on Polgon.
	/// @notice the token must be in the list of supported tokens.
	/// @notice This function can only be called by the owner.
	/// @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon.
	/// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
	/// @param _receiver The address of the recipient on the destination blockchain.
	/// @param _token token address.
	/// @param _amount token amount.
	/// @return messageId The ID of the message that was sent.
	function transferTokensPayNative(
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
		// Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
		// address(0) means fees are paid in native gas
		Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
			_receiver,
			_token,
			_amount,
			address(0)
		);

		uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

		if (fees > address(this).balance)
			revert NotEnoughBalance(address(this).balance, fees);

		IERC20(_token).approve(address(router), _amount);

		messageId = router.ccipSend{value: fees}(
			_destinationChainSelector,
			evm2AnyMessage
		);

		emit TokensTransferred(
			messageId,
			_destinationChainSelector,
			_receiver,
			_token,
			_amount,
			address(0),
			fees
		);

		return messageId;
	}

	/// @notice Construct a CCIP message.
	/// @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer.
	/// @param _receiver The address of the receiver.
	/// @param _token The token to be transferred.
	/// @param _amount The amount of the token to be transferred.
	/// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
	/// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
	function _buildCCIPMessage(
		address _receiver,
		address _token,
		uint256 _amount,
		address _feeTokenAddress
	) internal pure returns (Client.EVM2AnyMessage memory) {
		// Set the token amounts
		Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](
			1
		);
		Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
			token: _token,
			amount: _amount
		});
		tokenAmounts[0] = tokenAmount;
		// Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
		Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
			receiver: abi.encode(_receiver), // ABI-encoded receiver address
			data: '', // No data
			tokenAmounts: tokenAmounts, // The amount and type of token being transferred
			extraArgs: Client._argsToBytes(
				// Additional arguments, setting gas limit to 0 as we are not sending any data and non-strict sequencing mode
				Client.EVMExtraArgsV1({gasLimit: 0, strict: false})
			),
			// Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
			feeToken: _feeTokenAddress
		});
		return evm2AnyMessage;
	}

	function withdraw(address _beneficiary) public onlyOwner {
		uint256 amount = address(this).balance;

		if (amount == 0) revert NothingToWithdraw();

		(bool sent, ) = _beneficiary.call{value: amount}('');

		if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
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
