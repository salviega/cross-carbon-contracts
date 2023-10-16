// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum calculatorArgs {
	router
}

enum certificateArgs {
	name,
	symbol,
	baseURI
}

enum groceryArgs {
	moneySpentProteins,
	moneySpentFats,
	moneySpentCarbs
}

enum sendRequestStringArgs {
	flag,
	source
}

enum travelArgs {
	distance,
	nights
}

enum groceryReturns {
	proteinsEmission,
	fatsEmission,
	carbsEmission,
	foodEmission
}

enum travelReturns {
	flightEmission,
	hotelEmission,
	travelEmission
}
