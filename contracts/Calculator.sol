// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from '@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol';
import {ConfirmedOwner} from '@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol';
import {FunctionsRequest} from '@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol';

import {Travel} from './constants/structs/structs.sol';

contract Calculator is FunctionsClient, ConfirmedOwner {
	using FunctionsRequest for FunctionsRequest.Request;

	bytes public s_lastError;
	bytes public s_lastResponse;
	bytes32 public s_lastRequestId;

	mapping(bytes32 => Travel) public travels;

	error UnexpectedRequestID(bytes32 requestId);

	event Response(bytes32 indexed requestId, bytes response, bytes err);

	constructor(
		address router
	) FunctionsClient(router) ConfirmedOwner(msg.sender) {}

	/**
	 * @notice Send a simple request
	 * @param source JavaScript source code
	 * @param encryptedSecretsUrls Encrypted URLs where to fetch user secrets
	 * @param donHostedSecretsSlotID Don hosted secrets slotId
	 * @param donHostedSecretsVersion Don hosted secrets version
	 * @param args List of arguments accessible from within the source code
	 * @param bytesArgs Array of bytes arguments, represented as hex strings
	 * @param subscriptionId Billing ID
	 */
	function sendRequest(
		string memory source,
		bytes memory encryptedSecretsUrls,
		uint8 donHostedSecretsSlotID,
		uint64 donHostedSecretsVersion,
		string[] memory args,
		bytes[] memory bytesArgs,
		uint64 subscriptionId,
		uint32 gasLimit,
		bytes32 jobId
	) external returns (bytes32 requestId) {
		FunctionsRequest.Request memory req;
		req.initializeRequestForInlineJavaScript(source);
		if (encryptedSecretsUrls.length > 0)
			req.addSecretsReference(encryptedSecretsUrls);
		else if (donHostedSecretsVersion > 0) {
			req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
		}
		if (args.length > 0) req.setArgs(args);
		if (bytesArgs.length > 0) req.setBytesArgs(bytesArgs);
		s_lastRequestId = _sendRequest(
			req.encodeCBOR(),
			subscriptionId,
			gasLimit,
			jobId
		);
		return s_lastRequestId;
	}

	/**
	 * @notice Send a pre-encoded CBOR request
	 * @param request CBOR-encoded request data
	 * @param subscriptionId Billing ID
	 * @param gasLimit The maximum amount of gas the request can consume
	 * @param jobId ID of the job to be invoked
	 * @return requestId The ID of the sent request
	 */
	function sendRequestCBOR(
		bytes memory request,
		uint64 subscriptionId,
		uint32 gasLimit,
		bytes32 jobId
	) external onlyOwner returns (bytes32 requestId) {
		s_lastRequestId = _sendRequest(request, subscriptionId, gasLimit, jobId);
		return s_lastRequestId;
	}

	/**
	 * @notice Store latest result/error
	 * @param requestId The request ID, returned by sendRequest()
	 * @param response Aggregated response from the user code
	 * @param err Aggregated error from the user code or from the execution pipeline
	 * Either response or error parameter will be set, but never both
	 */
	function fulfillRequest(
		bytes32 requestId,
		bytes memory response,
		bytes memory err
	) internal override {
		if (s_lastRequestId != requestId) {
			revert('UnexpectedRequestID');
		}

		if (response.length > 0) {
			uint256 carbonFootprint = abi.decode(response, (uint256));

			uint256 factor = 10 ** 18;

			uint256 _distance = carbonFootprint / (factor * factor);
			carbonFootprint %= (factor * factor);

			uint256 _nights = carbonFootprint / factor;
			carbonFootprint %= factor;

			uint256 _total = carbonFootprint;

			travels[s_lastRequestId] = Travel({
				distance: _distance,
				nights: _nights,
				total: _total
			});
		}

		s_lastResponse = response;
		s_lastError = err;
		emit Response(requestId, s_lastResponse, s_lastError);
	}
}
