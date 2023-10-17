import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction, DeployResult } from 'hardhat-deploy/types'
import { developmentChains, networkConfig } from '../helper-hardhat-config'
import verify from '../helper-functions'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import {
	SEPOLIA_TCO2FAUCET,
	SEPOLIA_TCO2TOKEN,
	SEPOLIA_EPNS_COMM_ADDRESS,
	SEPOLIA_FUNCTIONS_ROUTER
} from '../constants/constants'

const deployCarbon: DeployFunction = async function (
	hre: HardhatRuntimeEnvironment
) {
	// @ts-ignore
	const { getNamedAccounts, deployments, network } = hre
	const { deploy, log } = deployments
	const { deployer } = await getNamedAccounts()

	log('----------------------------------------------------')
	log('------------------- Sepolia ------------------------')
	log('Deploying Carbon contract and waiting for confirmations...')

	let certificateArgs = [
		'Certificate', //_name
		'CERT', // _symbol
		'https://api.carbon.fyi/certificate/' // _baseURI
	]

	let calculatorArgs = [
		SEPOLIA_FUNCTIONS_ROUTER // _router
	]

	let args = [
		SEPOLIA_TCO2FAUCET, // _TCO2Faucet
		SEPOLIA_TCO2TOKEN, // _TCO2Token
		SEPOLIA_EPNS_COMM_ADDRESS, // _EPNS_COMM_ADDRESS
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
		process.env.SEPOLIASCAN_API_KEY
	) {
		await verify(CarbonContract.address, args)
	}

	log('----------------------------------------------------')
	log('Setting up the certificate owner...')
	log('\n')

	let certificateContract: Contract = await ethers.getContractAt(
		'Certificate',
		deployer
	)

	let transferCertificateOwnershipTx =
		await certificateContract.transferOwnership(CarbonContract.address)

	await transferCertificateOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the certificate contract.')
}

export default deployCarbon
deployCarbon.tags = ['all', 'sepolia']
