// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

contract Certificate is ERC721, ERC721URIStorage, Ownable {
	uint256 public tokenIdCounter;
	string baseURI;

	constructor(
		string memory _name,
		string memory _symbol,
		string memory _baseURI
	) ERC721(_name, _symbol) Ownable(msg.sender) {
		baseURI = _baseURI;
	}

	function safeMint(
		address _to,
		string memory _tokenURI
	) public onlyOwner returns (uint256) {
		uint256 tokenId = tokenIdCounter;
		tokenIdCounter++;

		_safeMint(_to, tokenId);
		_setTokenURI(tokenId, _tokenURI);

		return tokenId;
	}

	function approve(address, uint256) public pure override(ERC721, IERC721) {
		revert("Approve isn't allowed");
	}

	function setApprovalForAll(
		address,
		bool
	) public pure override(ERC721, IERC721) {
		revert("setApprovalForAll isn't allowed");
	}

	function transferFrom(
		address,
		address,
		uint256
	) public pure override(ERC721, IERC721) {
		revert("transferFrom isn't allowed");
	}

	function safeTransferFrom(
		address,
		address,
		uint256,
		bytes memory
	) public pure override(ERC721, IERC721) {
		revert("safeTransferFrom isn't allowed");
	}

	// The following functions are overrides required by Solidity.

	function tokenURI(
		uint256 tokenId
	) public view override(ERC721, ERC721URIStorage) returns (string memory) {
		return super.tokenURI(tokenId);
	}

	function supportsInterface(
		bytes4 interfaceId
	) public view override(ERC721, ERC721URIStorage) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}
