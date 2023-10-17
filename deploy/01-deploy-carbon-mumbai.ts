import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction, DeployResult } from 'hardhat-deploy/types'
import { developmentChains, networkConfig } from '../helper-hardhat-config'
import verify from '../helper-functions'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import {
	MUMBAI_TCO2FAUCET,
	MUMBAI_TCO2TOKEN,
	MUMBAI_EPNS_COMM_ADDRESS,
	MUMBAI_FUNCTIONS_ROUTER,
	MUMBAI_LINK_TOKEN
} from '../constants/constants'

const deployCarbon: DeployFunction = async function (
	hre: HardhatRuntimeEnvironment
) {
	// @ts-ignore
	const { getNamedAccounts, deployments, network } = hre
	const { deploy, log } = deployments
	const { deployer } = await getNamedAccounts()

	log('----------------------------------------------------')
	log('Deploying Carbon contract and waiting for confirmations...')

	let certificateArgs: string[] = [
		'Certificate', //_name
		'CERT', // _symbol
		'https://api.carbon.fyi/certificate/' // _baseURI
	]

	let calculatorArgs: string[] = [
		MUMBAI_FUNCTIONS_ROUTER // _router
	]

	let args: any[] = [
		MUMBAI_TCO2FAUCET, // _TCO2Faucet
		MUMBAI_TCO2TOKEN, // _TCO2Token
		MUMBAI_EPNS_COMM_ADDRESS, // _EPNS_COMM_ADDRESS
		certificateArgs, // _certificateArgs
		calculatorArgs // _calculatorArgs
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
	log('Setting up the certificate owner...')

	let transferCalculatorOwnershipTx =
		await calculatorContract.transferOwnership(CarbonContract.address)

	await transferCalculatorOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the calculator contract.')
	log('\n')
}

export default deployCarbon
deployCarbon.tags = ['all', 'mumbai']
