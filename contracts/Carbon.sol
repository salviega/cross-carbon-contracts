// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import './Calculator.sol';
import './Certificate.sol';

import './enums/enums.sol';
import './interfaces/ILinkToken.sol';
import './interfaces/ICertificate.sol';
import './interfaces/IPUSHCommInterface.sol';
import './interfaces/ITCO2Faucet.sol';
import './interfaces/ITCO2Token.sol';

contract Carbon is ERC20, ERC20Burnable, Ownable {
	using Strings for address;
	using Strings for uint;

	struct Travel {
		uint256 distance;
		uint256 nights;
		uint256 total;
	}

	ITCO2Faucet public TCO2FaucetExtense;
	ITCO2Token public TCO2TokenExtense;

	address public EPNS_COMM_ADDRESS;
	address public LINK_TOKEN_ADDRESS;
	address public CARBON_CERTIFICATE_ADDRESS;
	address public CARBON_CALCULATOR_ADDRESS;

	uint256 public TCO2TokensInContract;
	uint256 public carbonTokensMinted;

	event BougthCarbonCredits(address indexed buyer, uint256 amount);
	event RetiredCarbonCredits(
		address indexed buyer,
		uint256 amount,
		uint256 certificateId
	);

	constructor(
		address _TCO2Faucet,
		address _TCO2Token,
		address _EPNS_COMM_ADDRESS,
		address _LINK_TOKEN_ADDRESS,
		string[] memory _certificateArgs,
		address[] memory _calculatorArgs
	) ERC20('carbon', 'CARBON') Ownable(msg.sender) {
		require(
			_certificateArgs.length == 3,
			'_certificateArgs should be of length 3'
		);

		require(
			_calculatorArgs.length == 1,
			'_calculatorArgs should be of length 1'
		);

		TCO2FaucetExtense = ITCO2Faucet(_TCO2Faucet);
		TCO2TokenExtense = ITCO2Token(_TCO2Token);

		EPNS_COMM_ADDRESS = _EPNS_COMM_ADDRESS;
		LINK_TOKEN_ADDRESS = _LINK_TOKEN_ADDRESS;

		Certificate certificate = new Certificate(
			_certificateArgs[uint(certificateArgs.name)],
			_certificateArgs[uint(certificateArgs.symbol)],
			_certificateArgs[uint(certificateArgs.baseURI)]
		);

		Calculator calculator = new Calculator(
			_calculatorArgs[uint(calculatorArgs.router)]
		);

		CARBON_CERTIFICATE_ADDRESS = address(certificate);
		CARBON_CALCULATOR_ADDRESS = address(calculator);

		ILinkTokenInterface(_LINK_TOKEN_ADDRESS).approve(
			address(calculator),
			type(uint256).max
		);
	}

	receive() external payable {}

	function buyCarbonCredits(address _buyer, uint256 _amount) public onlyOwner {
		require(_amount > 0, 'Amount should be greater than 0');

		uint256 totalCarbonAfterMint = carbonTokensMinted + _amount;
		if (TCO2TokensInContract < totalCarbonAfterMint) {
			uint256 amountToWithdraw = totalCarbonAfterMint - TCO2TokensInContract;
			TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountToWithdraw);
			TCO2TokensInContract += amountToWithdraw;
		}

		_mint(_buyer, _amount);
		carbonTokensMinted += _amount;

		emit BougthCarbonCredits(_buyer, _amount);
	}

	function retireCarbonCredits(
		address _buyer,
		uint256 _amount
	) public onlyOwner {
		require(_amount > 0, 'Amount should be greater than 0');
		require(_amount <= balanceOf(_buyer), 'Insufficient CARBON tokens');

		if (TCO2TokensInContract >= _amount) {
			TCO2TokenExtense.retire(_amount);
			TCO2TokensInContract -= _amount;
		} else {
			uint256 amountFromOwner = _amount - TCO2TokensInContract;
			TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountFromOwner);
			TCO2TokenExtense.retire(_amount);
			TCO2TokensInContract = 0;
		}

		carbonTokensMinted -= _amount;
		burn(_amount);

		uint256 certificateId = ICertficate(CARBON_CERTIFICATE_ADDRESS).safeMint(
			_buyer,
			_amount
		);
		IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
			0xaA7880DB88D8e051428b5204817e58D8327340De, // from channel
			_buyer,
			bytes(
				abi.encodePacked(
					'0',
					'+',
					'3',
					'+',
					'Congrats!',
					'+',
					'You just received an offset certificate! ',
					'Your offset was ',
					(_amount / (10 ** uint(decimals()))).toString(),
					' CO2 Tons'
				)
			)
		);
		emit RetiredCarbonCredits(_buyer, _amount, certificateId);
	}

	// TODO: Calculate and Offset carbon footprint

	function calculateTravelFootprint(
		string memory _source,
		bytes memory _encryptedSecretsUrls,
		uint8 _donHostedSecretsSlotID,
		uint64 _donHostedSecretsVersion,
		string[] memory _args,
		bytes[] memory _bytesArgs,
		uint64 _subscriptionId,
		uint32 _gasLimit,
		bytes32 _jobId
	) public onlyOwner returns (Travel memory carbonFootprintTravel) {
		Calculator calculator = Calculator(CARBON_CALCULATOR_ADDRESS);

		uint256 requestId;

		requestId = calculator.sendRequest(
			_source,
			_encryptedSecretsUrls,
			_donHostedSecretsSlotID,
			_donHostedSecretsVersion,
			_args,
			_bytesArgs,
			_subscriptionId,
			_gasLimit,
			_jobId
		);

		Travel storage carbonFootprintTravel = calculator.travels[bytes32(requestId)];

		return carbonFootprintTravel;
	}

	function withdrawTCO2Tokens() public onlyOwner {
		uint256 amount = TCO2TokenExtense.balanceOf(address(this));
		require(TCO2TokenExtense.transfer(msg.sender, amount), 'Transfer failed');
	}

	function withdrawFunds() public onlyOwner {
		(bool response /*bytes memory data*/, ) = msg.sender.call{
			value: address(this).balance
		}('');
		require(response, 'Transfer failed');
	}

	function transfer(
		address to,
		uint256 amount
	) public virtual override returns (bool) {
		address owner = _msgSender();
		_transfer(owner, to, amount);

		IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
			0xaA7880DB88D8e051428b5204817e58D8327340De, // from channel
			to,
			bytes(
				string(
					abi.encodePacked(
						'0',
						'+',
						'3',
						'+',
						'Congrats!',
						'+',
						owner.toHexString(),
						' transferred ',
						(amount / (10 ** uint(decimals()))).toString(),
						' CARBON to you!'
					)
				)
			)
		);

		return true;
	}

	function transferFrom(
		address from,
		address to,
		uint256 amount
	) public virtual override returns (bool) {
		address spender = _msgSender();
		_spendAllowance(from, spender, amount);
		_transfer(from, to, amount);

		IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
			0xaA7880DB88D8e051428b5204817e58D8327340De,
			to,
			bytes(
				string(
					abi.encodePacked(
						'0',
						'+',
						'3',
						'+',
						'Congrats!',
						'+',
						spender.toHexString(),
						' transferred ',
						(amount / (10 ** uint(decimals()))).toString(),
						' CARBON to you!'
					)
				)
			)
		);

		return true;
	}
}
