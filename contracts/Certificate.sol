// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract Certificate is ERC721, ERC721Enumerable, Ownable {
	struct NFT {
		uint256 id;
		string uri;
	}

	string baseURI;
	uint256 public tokenIdCounter;

	constructor(
		string memory _name,
		string memory _symbol,
		string memory _baseURI
	) ERC721(_name, _symbol) Ownable(msg.sender) {
		baseURI = _baseURI;
	}

	function safeMint(address _to) public onlyOwner returns (uint256) {
		uint256 tokenId = tokenIdCounter;
		tokenIdCounter++;

		_safeMint(_to, tokenId);
		return tokenId;
	}

	function changeBaseURI(string memory _baseURI) external onlyOwner {
		baseURI = _baseURI;
	}

	function tokensOfOwner(address _owner) public view returns (NFT[] memory) {
		uint256 tokenCount = balanceOf(_owner);

		if (tokenCount == 0) {
			return new NFT[](0);
		} else {
			NFT[] memory tokensData = new NFT[](tokenCount);

			for (uint256 i = 0; i < tokenCount; i++) {
				uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
				tokensData[i] = NFT({id: tokenId, uri: tokenURI(tokenId)});
			}

			return tokensData;
		}
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

	function tokenURI(
		uint256 tokenId
	) public view override returns (string memory) {
		_requireOwned(tokenId);

		return baseURI;
	}

	// The following functions are overrides required by Solidity.

	function _update(
		address to,
		uint256 tokenId,
		address auth
	) internal override(ERC721, ERC721Enumerable) returns (address) {
		return super._update(to, tokenId, auth);
	}

	function _increaseBalance(
		address account,
		uint128 value
	) internal override(ERC721, ERC721Enumerable) {
		super._increaseBalance(account, value);
	}

	function supportsInterface(
		bytes4 interfaceId
	) public view override(ERC721, ERC721Enumerable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}
