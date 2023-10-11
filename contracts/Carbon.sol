// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

import './Certificate.sol';

import './enums/enums.sol';
import './interfaces/ICertificate.sol';
import './interfaces/IPUSHCommInterface.sol';
import './interfaces/ITCO2Faucet.sol';
import './interfaces/ITCO2Token.sol';
import './helpers/helpers.sol';

contract Carbon is ERC20, ERC20Burnable, Ownable, Helpers {
	ITCO2Faucet public TCO2FaucetExtense;
	ITCO2Token public TCO2TokenExtense;

	address public EPNS_COMM_ADDRESS;
	address public CARBON_CERTIFICATE_ADDRESS;

	uint256 public TCO2FaucetTokensInContract;
	uint256 public carbonTokensMinted;

	event BougthCarbonCredits(address indexed buyer, uint256 amount);
	event OffsetCarbonFootprint(
		address indexed buyer,
		uint256 amount,
		uint256 certificateId
	);

	constructor(
		address _TCO2Faucet,
		address _TCO2Token,
		address _EPNS_COMM_ADDRESS,
		string memory _name,
		string memory _symbol,
		string[] memory _certificateArgs
	) ERC20(_name, _symbol) Ownable() {
		require(
			_certificateArgs.length == 3,
			'_certificateArgs should be of length 3'
		);

		TCO2FaucetExtense = ITCO2Faucet(_TCO2Faucet);
		TCO2TokenExtense = ITCO2Token(_TCO2Token);
		EPNS_COMM_ADDRESS = _EPNS_COMM_ADDRESS;

		Certificate certificate = new Certificate(
			_certificateArgs[uint(certificateArgs.name)],
			_certificateArgs[uint(certificateArgs.symbol)],
			_certificateArgs[uint(certificateArgs.baseURI)]
		);

		CARBON_CERTIFICATE_ADDRESS = address(certificate);
	}

	function buyCarbonCredits(address _buyer, uint256 _amount) public onlyOwner {
		require(_amount > 0, 'Amount should be greater than 0');

		uint256 totalCarbonAfterMint = carbonTokensMinted + _amount;
		if (TCO2FaucetTokensInContract < totalCarbonAfterMint) {
			uint256 amountToWithdraw = totalCarbonAfterMint -
				TCO2FaucetTokensInContract;
			TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountToWithdraw);
			TCO2FaucetTokensInContract += amountToWithdraw;
		}

		_mint(_buyer, _amount);
		carbonTokensMinted += _amount;

		emit BougthCarbonCredits(_buyer, _amount);
	}

	function offsetCarbonFootprint(
		address _buyer,
		uint256 _amount
	) public onlyOwner {
		require(_amount > 0, 'Amount should be greater than 0');
		require(_amount <= balanceOf(_buyer), 'Insufficient CARBON tokens');

		if (TCO2FaucetTokensInContract >= _amount) {
			TCO2TokenExtense.retire(_amount);
			TCO2FaucetTokensInContract -= _amount;
		} else {
			uint256 amountFromOwner = _amount - TCO2FaucetTokensInContract;
			TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountFromOwner);
			TCO2TokenExtense.retire(_amount);
			TCO2FaucetTokensInContract = 0;
		}

		carbonTokensMinted -= _amount;
		burn(_amount);

		uint256 certificateId = ICertficate(CARBON_CERTIFICATE_ADDRESS).safeMint(
			_buyer
		);

		emit OffsetCarbonFootprint(_buyer, _amount, certificateId);
	}

	// TODO: Calculate and Offset carbon footprint

	function transfer(
		address to,
		uint256 amount
	) public virtual override returns (bool) {
		address owner = _msgSender();
		_transfer(owner, to, amount);

		IPUSHCommInterface(EPNS_COMM_ADDRESS).sendNotification(
			0x050Ca75E3957c37dDF26D58046d8F9967B88190c, // from channel
			to,
			bytes(
				string(
					abi.encodePacked(
						'0',
						'+',
						'3',
						'+',
						'Tranfer Alert',
						'+',
						'Hooray! ',
						addressToString(msg.sender),
						' sent ',
						uint2str(amount / (10 ** uint(decimals()))),
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
			0x050Ca75E3957c37dDF26D58046d8F9967B88190c, // from channel
			to,
			bytes(
				string(
					abi.encodePacked(
						'0',
						'+',
						'3',
						'+',
						'Transfer Alert',
						'+',
						addressToString(from),
						' transferred ',
						uint2str(amount / (10 ** uint(decimals()))),
						' CARBON to you!'
					)
				)
			)
		);

		return true;
	}
}
