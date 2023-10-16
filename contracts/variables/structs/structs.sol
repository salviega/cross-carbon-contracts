// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct Travel {
	string distance;
	string nights;
	uint256 flightEmission;
	uint256 hotelEmission;
	uint256 travelEmission;
	address buyer;
}

struct Grocery {
	string moneySpentProteins;
	string moneySpentFats;
	string moneySpentCarbs;
	uint256 proteinsEmission;
	uint256 fatsEmission;
	uint256 carbsEmission;
	uint256 foodEmission;
	address buyer;
}
