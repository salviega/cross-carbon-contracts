// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from '@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol';
import {ConfirmedOwner} from '@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol';
import {FunctionsRequest} from '@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol';

import './helpers/helpers.sol';

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract Calculator is FunctionsClient, ConfirmedOwner, Helpers {
	using FunctionsRequest for FunctionsRequest.Request;

	bytes32 public s_lastRequestId;
	bytes public s_lastResponse;
	bytes public s_lastError;

	address public s_lastBuyer;
	string public s_lastFlag;
	string[] public s_lastArgs;
	uint256[] public s_lastReturns;

	error UnexpectedRequestID(bytes32 requestId);

	event Response(bytes32 indexed requestId, bytes response, bytes err);

	event CarbonFootprintCalculated(
		bytes32 indexed requestId,
		string s_lastFlag,
		string[] s_lastArgs,
		uint256[] s_lastReturns,
		address s_lastBuyer
	);

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
		address buyer,
		string memory flag,
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

		s_lastBuyer = buyer;
		s_lastFlag = flag;
		s_lastArgs = args;

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
			revert UnexpectedRequestID(requestId);
		}

		if (response.length > 0 && equal(s_lastFlag, 'travel')) {
			uint256 carbonFootprint = abi.decode(response, (uint256));
			uint256 factor = 10 ** 18;

			uint256 _distance = carbonFootprint / (factor * factor);
			carbonFootprint %= (factor * factor);

			uint256 _nights = carbonFootprint / factor;
			carbonFootprint %= factor;

			uint256 _total = carbonFootprint;

			s_lastReturns = new uint256[](3);
			s_lastReturns[0] = _distance;
			s_lastReturns[1] = _nights;
			s_lastReturns[2] = _total;

			s_lastResponse = response;
			s_lastError = err;

			emit CarbonFootprintCalculated(
				requestId,
				s_lastFlag,
				s_lastArgs,
				s_lastReturns,
				s_lastBuyer
			);
		} else if (response.length > 0 && equal(s_lastFlag, 'grocery')) {
			uint256 carbonFootprint = abi.decode(response, (uint256));
			uint256 factor = 10 ** 18;

			uint256 _proteins = carbonFootprint / (factor * factor * factor);
			carbonFootprint %= (factor * factor * factor);

			uint256 _fats = carbonFootprint / (factor * factor);
			carbonFootprint %= (factor * factor);

			uint256 _carbs = carbonFootprint / factor;
			carbonFootprint %= factor;

			uint256 _total = carbonFootprint;

			s_lastReturns = new uint256[](4);
			s_lastReturns[0] = _proteins;
			s_lastReturns[1] = _fats;
			s_lastReturns[2] = _carbs;
			s_lastReturns[3] = _total;

			emit CarbonFootprintCalculated(
				requestId,
				s_lastFlag,
				s_lastArgs,
				s_lastReturns,
				s_lastBuyer
			);
		}

		emit Response(requestId, s_lastResponse, s_lastError);
	}
}
