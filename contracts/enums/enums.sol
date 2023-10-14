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

enum groseryArgs {
	moneySpentProteins,
	moneySpentFats,
	moneySpentCarbs
}

enum travelArgs {
	distance,
	nights
}

enum groseryReturns {
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
