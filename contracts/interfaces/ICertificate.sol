// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';

interface ICertficate is IERC721, IERC721Metadata {
	function safeMint(address to) external returns (uint256);

	function changeBaseURI(string memory _baseURI) external;
}
