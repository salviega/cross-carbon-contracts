import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction, DeployResult } from 'hardhat-deploy/types'
import { developmentChains, networkConfig } from '../helper-hardhat-config'
import verify from '../helper-functions'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import {
	OPTIMISM_TCO2FAUCET,
	OPTIMISM_TCO2TOKEN,
	OPTIMISM_EPNS_COMM_ADDRESS,
	OPTIMISM_FUNCTIONS_ROUTER,
	OPTIMISM_CCIP_ROUTER,
	OPTIMISM_LINK_TOKEN
} from '../constants/constants'
import IERC20ExtendedJson from '../artifacts/contracts/interfaces/IERC20Extended.sol/IERC20Extended.json'

const deployCarbon: DeployFunction = async function (
	hre: HardhatRuntimeEnvironment
) {
	// @ts-ignore
	const { getNamedAccounts, deployments, network } = hre
	const { deploy, log } = deployments
	const { deployer } = await getNamedAccounts()

	log('----------------------------------------------------')
	log('------------------- OPTIMISM -------------------------')
	log('Deploying Carbon contract and waiting for confirmations...')

	let carbonArgs: string[] = [
		OPTIMISM_TCO2FAUCET, // _TCO2Faucet,
		OPTIMISM_TCO2TOKEN, // _TCO2Token,
		OPTIMISM_EPNS_COMM_ADDRESS // _EPNS_COMM_ADDRESS
	]

	let certificateArgs: string[] = [
		'Certificate', //_name
		'CERT', // _symbol
		'' // _baseURI
	]

	let calculatorArgs: string[] = [
		OPTIMISM_FUNCTIONS_ROUTER // _router
	]

	let communicatorArgs: string[] = [
		OPTIMISM_CCIP_ROUTER, // router
		OPTIMISM_LINK_TOKEN
	]

	let args: any[] = [
		carbonArgs, // _carbonArgs
		certificateArgs, // _certificateArgs
		calculatorArgs, // _calculatorArgs
		communicatorArgs // _communicatorArgs
	]

	let CarbonContract: DeployResult = await deploy('Carbon', {
		from: deployer,
		args: args,
		log: true,
		waitConfirmations: networkConfig[network.name].blockConfirmations || 1
	})

	log('\n')

	if (
		!developmentChains.includes(network.name) &&
		process.env.POLYGONSCAN_API_KEY
	) {
		await verify(CarbonContract.address, args)
	}

	let carbonContract: Contract = await ethers.getContractAt(
		'Carbon',
		CarbonContract.address
	)

	await verify(await carbonContract.CARBON_CALCULATOR_ADDRESS(), calculatorArgs)

	log('----------------------------------------------------')
	log('Setting up the certificate owner...')

	let certificateContract: Contract = await ethers.getContractAt(
		'Certificate',
		deployer
	)

	let transferCertificateOwnershipTx =
		await certificateContract.transferOwnership(CarbonContract.address)

	await transferCertificateOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the certificate contract.')
	log('\n')

	let calculatorContract: Contract = await ethers.getContractAt(
		'Calculator',
		deployer
	)

	log('----------------------------------------------------')
	log('Setting up the calculator owner...')

	let transferCalculatorOwnershipTx =
		await calculatorContract.transferOwnership(CarbonContract.address)

	await transferCalculatorOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the calculator contract.')
	log('\n')

	let communicatorContract: Contract = await ethers.getContractAt(
		'Communicator',
		deployer
	)

	log('----------------------------------------------------')
	log('Setting up the communicator owner...')

	let transferCommunicatorOwnershipTx =
		await communicatorContract.transferOwnership(CarbonContract.address)

	await transferCommunicatorOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the communicator contract.')
	log('\n')

	log('Carbon contract is the new owner of the communicator contract.')
	log('\n')

	const LINK_DECIMALS = 18
	const LINK_AMOUNT = ethers.parseUnits('2', LINK_DECIMALS)

	const linkTokenContract: Contract = await ethers.getContractAt(
		IERC20ExtendedJson.abi,
		OPTIMISM_LINK_TOKEN
	)

	log('----------------------------------------------------')
	log('Transferring 2 LINKs to the Communicator contract...')
	log('\n')

	const transferLinkTx = await linkTokenContract.transfer(
		communicatorContract.address,
		LINK_AMOUNT
	)
	await transferLinkTx.wait(1)

	log('2 LINKs transferred to the Communicator contract.')
	log('\n')
}

export default deployCarbon
deployCarbon.tags = ['all', 'optimism']
