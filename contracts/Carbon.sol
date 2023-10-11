// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/ITCO2Faucet.sol';
import './interfaces/ITCO2Token.sol';

contract Carbon is ERC20, ERC20Burnable, Ownable {
	ITCO2Faucet public TCO2FaucetExtense;
	ITCO2Token public TCO2TokenExtense;

	uint256 public TCO2FaucetTokensInContract;
	uint256 public carbonTokensMinted;

	constructor(
		address _TCO2Faucet,
		address _TCO2Token,
		string memory _name,
		string memory _symbol
	) ERC20(_name, _symbol) Ownable() {
		TCO2FaucetExtense = ITCO2Faucet(_TCO2Faucet);
		TCO2TokenExtense = ITCO2Token(_TCO2Token);
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
	}

	function burnCarbonCredits(uint256 _amount) public {
		require(_amount > 0, 'Amount should be greater than 0');
		require(_amount <= balanceOf(msg.sender), 'Insufficient CARBON tokens');

		carbonTokensMinted -= _amount;
		burn(_amount);

		if (TCO2FaucetTokensInContract >= _amount) {
			TCO2TokenExtense.retire(_amount);
			TCO2FaucetTokensInContract -= _amount;
		} else {
			uint256 amountFromOwner = _amount - TCO2FaucetTokensInContract;
			TCO2FaucetExtense.withdraw(address(TCO2TokenExtense), amountFromOwner);
			TCO2TokenExtense.retire(_amount);
			TCO2FaucetTokensInContract = 0;
		}
	}

	// TODO: Offset carbon footprint
}
