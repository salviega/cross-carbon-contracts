// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import './Calculator.sol';
import './Certificate.sol';
import './Communicator.sol';

import './enums/enums.sol';
import './interfaces/ILinkToken.sol';
import './interfaces/ICertificate.sol';
import './interfaces/ICommunicator.sol';
import './interfaces/IPUSHCommInterface.sol';
import './interfaces/ITCO2Faucet.sol';
import './interfaces/ITCO2Token.sol';
import './helpers/helpers.sol';

import {Grocery, Travel} from './variables/structs/structs.sol';

contract Carbon is ERC20, ERC20Burnable, Ownable, Helpers {
	using Strings for address;
	using Strings for string;
	using Strings for uint;

	ITCO2Faucet public TCO2FaucetExtense;
	ITCO2Token public TCO2TokenExtense;

	address public EPNS_COMM_ADDRESS;
	address public CARBON_CERTIFICATE_ADDRESS;
	address public CARBON_CALCULATOR_ADDRESS;
	address public CARBON_COMMUNICATOR_ADDRESS;

	uint256 public TCO2TokensInContract;
	uint256 public carbonTokensMinted;
	uint256 public carbonTokensBurned;

	bool public isMumbai;

	mapping(address => uint256) public carbonTokensBurnedPerUser;
	mapping(bytes32 => Travel) public travelRequests;
	mapping(bytes32 => Grocery) public groceryRequests;

	event BougthCarbonCredits(address indexed buyer, uint256 amount);

	event BougthCarbonCreditsCrosschain(
		address indexed buyer,
		uint256 amount,
		string network
	);

	event RetiredCarbonCredits(
		address indexed buyer,
		uint256 amount,
		uint256 certificateId
	);

	event RetiredCarbonCreditsCrosschain(
		address indexed buyer,
		uint256 amount,
		string network
	);

	event GroceryCarbonFootprintOffset(
		bytes32 indexed requestId,
		string moneySpentProteins,
		string moneySpentFats,
		string moneySpentCarbs,
		uint256 proteinsEmission,
		uint256 fatsEmission,
		uint256 carbsEmission,
		uint256 foodEmission,
		address buyer
	);

	event TravelCarbonFootprintOffset(
		bytes32 indexed requestId,
		string distance,
		string nights,
		uint256 flightEmission,
		uint256 hotelEmission,
		uint256 travelEmission,
		address buyer
	);

	event TransferCrosschain(
		address indexed from,
		address indexed to,
		uint256 amount,
		string network
	);

	event TransferFromCrosschain(
		address indexed sender,
		address indexed from,
		address indexed to,
		uint256 amount,
		string network
	);

	constructor(
		address[] memory _carbonArgs,
		string[] memory _certificateArgs,
		address[] memory _calculatorArgs,
		address[] memory _communicatorArgs
	) ERC20('carbon', 'CARBON') Ownable(msg.sender) {
		require(_carbonArgs.length == 3, '_carbonArgs should be of length 3');

		require(
			_certificateArgs.length == 3,
			'_certificateArgs should be of length 3'
		);

		require(
			_calculatorArgs.length == 1,
			'_calculatorArgs should be of length 1'
		);

		require(
			_communicatorArgs.length == 2,
			'_communicatorArgs should be of length 2'
		);

		isMumbai = _validateAddresses(
			_carbonArgs[uint(carbonArgs._TCO2Faucet)],
			_carbonArgs[uint(carbonArgs._TCO2Token)],
			_carbonArgs[uint(carbonArgs._EPNS_COMM_ADDRESS)]
		);

		TCO2FaucetExtense = ITCO2Faucet(_carbonArgs[uint(carbonArgs._TCO2Faucet)]);
		TCO2TokenExtense = ITCO2Token(_carbonArgs[uint(carbonArgs._TCO2Token)]);

		EPNS_COMM_ADDRESS = _carbonArgs[uint(carbonArgs._EPNS_COMM_ADDRESS)];

		Certificate certificate = new Certificate(
			_certificateArgs[uint(certificateArgs.name)],
			_certificateArgs[uint(certificateArgs.symbol)],
			_certificateArgs[uint(certificateArgs.baseURI)]
		);

		CARBON_CERTIFICATE_ADDRESS = address(certificate);

		if (isMumbai) {
			Calculator calculator = new Calculator(
				_calculatorArgs[uint(calculatorArgs.router)]
			);
			CARBON_CALCULATOR_ADDRESS = address(calculator);
		} else {
			CARBON_CALCULATOR_ADDRESS = address(0);
		}

		Communicator communicator = new Communicator(
			_communicatorArgs[uint(communicatorArgs.router)],
			_communicatorArgs[uint(communicatorArgs.link)]
		);

		CARBON_COMMUNICATOR_ADDRESS = address(communicator);
	}

	function buyCarbonCredits(address _buyer, uint256 _amount) public {
		if (isMumbai) {
			require(_amount > 0, 'Amount should be greater than 0');

			uint256 totalCarbonAfterMint = carbonTokensMinted + _amount;
			if (TCO2TokensInContract < totalCarbonAfterMint) {
				uint256 amountToWithdraw = totalCarbonAfterMint - TCO2TokensInContract;
				TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountToWithdraw);
				TCO2TokensInContract += amountToWithdraw;
			}

			_mint(_buyer, _amount);
			carbonTokensMinted += _amount;

			IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
				0xaA7880DB88D8e051428b5204817e58D8327340De, // from channel
				_buyer,
				bytes(
					string(
						abi.encodePacked(
							'0',
							'+',
							'3',
							'+',
							'Congrats!',
							'+',
							'You just bought ',
							(_amount / (10 ** uint(decimals()))).toString(),
							' CARBON!'
						)
					)
				)
			);

			emit BougthCarbonCredits(_buyer, _amount);
			return;
		}

		revert('Only Mumbai network is supported');
	}

	function buyCarbonCreditsCrosschain(
		address _buyer,
		uint256 _amount,
		string memory messageContent, // {flag: 'buy', buyer: 0x123, amount: 1000, network: 'albitrum' || 'mumbai' || 'sepolia' || 'optimism'}
		uint64 _destinationChainSelector
	) public {
		if (!isMumbai) {
			require(_amount > 0, 'Amount should be greater than 0');

			ICommunicator(CARBON_COMMUNICATOR_ADDRESS).send(
				_buyer,
				messageContent,
				_destinationChainSelector
			);

			_mint(_buyer, _amount);
			return;
		}

		revert('Not supported in Mumbai network');
	}

	function websocketBuyCarbonCredits(
		address _buyer,
		uint256 _amount,
		string memory _network
	) external onlyOwner {
		if (isMumbai) {
			uint256 totalCarbonAfterMint = carbonTokensMinted + _amount;
			if (TCO2TokensInContract < totalCarbonAfterMint) {
				uint256 amountToWithdraw = totalCarbonAfterMint - TCO2TokensInContract;
				TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountToWithdraw);
				TCO2TokensInContract += amountToWithdraw;
			}

			carbonTokensMinted += _amount;

			emit BougthCarbonCreditsCrosschain(_buyer, _amount, _network);
			return;
		}
		revert('Only Mumbai network is supported');
	}

	function retireCarbonCredits(address _buyer, uint256 _amount) public {
		if (isMumbai) {
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
			carbonTokensBurned += _amount;
			carbonTokensBurnedPerUser[_buyer] += _amount;

			burn(_amount);

			uint256 certificateId = ICertficate(CARBON_CERTIFICATE_ADDRESS).safeMint(
				_buyer
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
			return;
		}

		revert('Only Mumbai network is supported');
	}

	function retireCarbonCreditsCrosschain(
		address _buyer,
		uint256 _amount,
		string memory messageContent, // {flag: 'retire', buyer: 0x123, amount: 1000, network: 'albitrum' || 'mumbai' || 'sepolia' || 'optimism'}
		uint64 _destinationChainSelector
	) public {
		if (!isMumbai) {
			require(_amount > 0, 'Amount should be greater than 0');
			require(_amount <= balanceOf(_buyer), 'Insufficient CARBON tokens');

			ICommunicator(CARBON_COMMUNICATOR_ADDRESS).send(
				_buyer,
				messageContent,
				_destinationChainSelector
			);

			burn(_amount);

			ICertficate(CARBON_CERTIFICATE_ADDRESS).safeMint(_buyer);

			return;
		}

		revert('Not supported in Mumbai network');
	}

	function websocketRetireCarbonCredits(
		address _buyer,
		uint256 _amount,
		string memory _network
	) external onlyOwner {
		if (isMumbai) {
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
			carbonTokensBurned += _amount;
			carbonTokensBurnedPerUser[_buyer] += _amount;

			emit RetiredCarbonCreditsCrosschain(_buyer, _amount, _network);
			return;
		}
		revert('Only Mumbai network is supported');
	}

	function offsetCarbonFootprint(
		bytes32 _requestId,
		string calldata _flag,
		string[] calldata _args,
		uint256[] calldata _returns,
		address _buyer
	) public {
		if (equal(_flag, 'travel')) {
			Travel memory travel = Travel(
				_args[uint(travelArgs.distance)],
				_args[uint(travelArgs.nights)],
				_returns[uint(travelReturns.flightEmission)],
				_returns[uint(travelReturns.hotelEmission)],
				_returns[uint(travelReturns.travelEmission)],
				_buyer
			);

			travelRequests[_requestId] = travel;

			buyCarbonCredits(travel.buyer, travel.travelEmission);
			retireCarbonCredits(travel.buyer, travel.travelEmission);

			emit TravelCarbonFootprintOffset(
				_requestId,
				travel.distance,
				travel.nights,
				travel.flightEmission,
				travel.hotelEmission,
				travel.travelEmission,
				travel.buyer
			);

			return;
		} else if (equal(_flag, 'grocery')) {
			Grocery memory grocery = Grocery(
				_args[uint(groceryArgs.moneySpentProteins)],
				_args[uint(groceryArgs.moneySpentFats)],
				_args[uint(groceryArgs.moneySpentCarbs)],
				_returns[uint(groceryReturns.proteinsEmission)],
				_returns[uint(groceryReturns.fatsEmission)],
				_returns[uint(groceryReturns.carbsEmission)],
				_returns[uint(groceryReturns.foodEmission)],
				_buyer
			);

			groceryRequests[_requestId] = grocery;

			buyCarbonCredits(grocery.buyer, grocery.foodEmission);
			retireCarbonCredits(grocery.buyer, grocery.foodEmission);

			emit GroceryCarbonFootprintOffset(
				_requestId,
				grocery.moneySpentProteins,
				grocery.moneySpentFats,
				grocery.moneySpentCarbs,
				grocery.proteinsEmission,
				grocery.fatsEmission,
				grocery.carbsEmission,
				grocery.foodEmission,
				grocery.buyer
			);

			return;
		}
		revert('Invalid flag');
	}

	function withdrawTCO2Tokens() external onlyOwner {
		uint256 amount = TCO2TokenExtense.balanceOf(address(this));
		require(TCO2TokenExtense.transfer(msg.sender, amount), 'Transfer failed');
	}

	function withdrawFunds() external onlyOwner {
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

		if (isMumbai) {
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
		}

		return true;
	}

	function transferCrosschain(
		address to,
		uint256 amount,
		string memory messageContent, // {flag: 'transfer', from: 0x123, to:0xabc, amount: 1000, network: 'albitrum' || 'mumbai' || 'sepolia' || 'optimism'}
		uint64 destinationChainSelector
	) public {
		ICommunicator(CARBON_COMMUNICATOR_ADDRESS).send(
			to,
			messageContent,
			destinationChainSelector
		);

		burn(amount);
	}

	function websocketTransfer(
		address _from,
		address _to,
		uint256 _amount,
		string memory _network
	) external onlyOwner {
		_mint(_to, _amount);

		emit TransferCrosschain(_from, _to, _amount, _network);
		return;
	}

	function transferFrom(
		address from,
		address to,
		uint256 amount
	) public virtual override returns (bool) {
		address spender = _msgSender();
		_spendAllowance(from, spender, amount);
		_transfer(from, to, amount);

		if (isMumbai) {
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
							spender.toHexString(),
							' transferred ',
							(amount / (10 ** uint(decimals()))).toString(),
							' CARBON to you!'
						)
					)
				)
			);
		}

		return true;
	}

	function transferFromCrosschain(
		address from,
		address to,
		uint256 amount,
		string memory messageContent, // {flag: 'transferFrom', sender: 0x123, from:0x1b2, to:0xabc, amount: 1000, network: 'albitrum' || 'mumbai' || 'sepolia' || 'optimism'}
		uint64 destinationChainSelector
	) public {
		ICommunicator(CARBON_COMMUNICATOR_ADDRESS).send(
			to,
			messageContent,
			destinationChainSelector
		);

		burn(amount);
	}

	function websocketTransferFrom(
		address _sender,
		address _from,
		address _to,
		uint256 _amount,
		string memory _network
	) external onlyOwner {
		_mint(_to, _amount);

		emit TransferFromCrosschain(_sender, _from, _to, _amount, _network);
		return;
	}
}
