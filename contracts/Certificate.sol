// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import './interfaces/IPUSHCommInterface.sol';
import './helpers/helpers.sol';
import './constants/constants.sol';

contract Certificate is ERC721, Ownable, Helpers {
	uint256 public tokenIdCounter;
	string baseURI;

	constructor(
		string memory _name,
		string memory _symbol,
		string memory _baseURI
	) ERC721(_name, _symbol) Ownable(msg.sender) {
		baseURI = _baseURI;
	}

	function safeMint(address _to, uint256 _amount ,address _EPNS_COMM_ADDRESS) public onlyOwner returns (uint256) {
		uint256 tokenId = tokenIdCounter;
		tokenIdCounter++;

		_safeMint(_to, tokenId);

		IPUSHCommInterface(_EPNS_COMM_ADDRESS).sendNotification(
			0xaA7880DB88D8e051428b5204817e58D8327340De, // from channel
			_to,
			bytes(
				string(
					abi.encodePacked(
						'0',
						'+',
						'3',
						'+',
						'Congrats!',
						'+',
						'You just received an offset certificate! ',
						'Your offset was ',
						uint2str(_amount / (10 ** uint(DECIMALS))),
						' CO2 Tons'
					)
				)
			)
		);

		return tokenId;
	}

	function approve(address, uint256) public pure override {
		revert("Approve isn't allowed");
	}

	function setApprovalForAll(address, bool) public pure override {
		revert("setApprovalForAll isn't allowed");
	}

	function transferFrom(address, address, uint256) public pure override {
		revert("transferFrom isn't allowed");
	}

	function safeTransferFrom(
		address,
		address,
		uint256,
		bytes memory
	) public pure override {
		revert("safeTransferFrom isn't allowed");
	}

	function tokenURI(
		uint256 tokenId
	) public view override returns (string memory) {
		_requireOwned(tokenId);

		return baseURI;
	}
}
