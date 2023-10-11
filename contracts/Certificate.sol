// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

contract Certificate is ERC721, Ownable {
	using Counters for Counters.Counter;

	Counters.Counter public tokenIdCounter;
	string baseURI;

	constructor(
		string memory _name,
		string memory _symbol,
		string memory _baseURI
	) ERC721(_name, _symbol) Ownable() {
		baseURI = _baseURI;
	}

	function safeMint(address to) public onlyOwner returns (uint256) {
		uint256 tokenId = tokenIdCounter.current();
		tokenIdCounter.increment();

		_safeMint(to, tokenId);

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
		_requireMinted(tokenId);

		return baseURI;
	}
}
