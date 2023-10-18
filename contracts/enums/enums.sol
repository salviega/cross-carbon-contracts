// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum calculatorArgs {
	router
}

enum carbonArgs {
	_TCO2Faucet,
	_TCO2Token,
	_EPNS_COMM_ADDRESS
}

enum certificateArgs {
	name,
	symbol,
	baseURI
}

enum communicatorArgs {
	router,
	link
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
