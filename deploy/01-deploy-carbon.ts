import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction, DeployResult } from 'hardhat-deploy/types'
import { developmentChains, networkConfig } from '../helper-hardhat-config'
import verify from '../helper-functions'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'

const deployCarbon: DeployFunction = async function (
	hre: HardhatRuntimeEnvironment
) {
	// @ts-ignore
	const { getNamedAccounts, deployments, network } = hre
	const { deploy, log } = deployments
	const { deployer } = await getNamedAccounts()

	log('----------------------------------------------------')
	log('Deploying Carbon contract and waiting for confirmations...')

	const certificateArgs: string[] = [
		'Certificate', //_name
		'CERT', // _symbol
		'https://api.carbon.fyi/certificate/' // _baseURI
	]

	const calculatorArgs: string[] = [
		'0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C' // _router
	]

	const args: any[] = [
		'0x996b39698CF96A70B7a7005B5d1924a66C5E8f0e', // _TCO2Faucet
		'0xa5831eb637dff307395b5183c86B04c69C518681', // _TCO2Token
		'0xb3971BCef2D791bc4027BbfedFb47319A4AAaaAa', // _EPNS_COMM_ADDRESS
		'0x326C977E6efc84E512bB9C30f76E30c160eD06FB', // _LINK_TOKEN_ADDRESS
		certificateArgs, // _certificateArgs
		calculatorArgs // _calculatorArgs
	]

	const CarbonContract: DeployResult = await deploy('Carbon', {
		from: deployer,
		args: args,
		log: true,
		waitConfirmations: networkConfig[network.name].blockConfirmations || 1
	})

	if (
		!developmentChains.includes(network.name) &&
		(process.env.CELOSCAN_API_KEY || process.env.POLYGONSCAN_API_KEY)
	) {
		await verify(CarbonContract.address, args)
	}

	const carbonContract: Contract = await ethers.getContractAt(
		'Carbon',
		CarbonContract.address
	)

	log('----------------------------------------------------')
	log('Setting up the certificate owner...')

	const certificateContract: Contract = await ethers.getContractAt(
		'Certificate',
		deployer
	)

	const transferCertificateOwnershipTx =
		await certificateContract.transferOwnership(CarbonContract.address)

	await transferCertificateOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the certificate contract.')
	log('\n')

	const calculatorContract: Contract = await ethers.getContractAt(
		'Calculator',
		deployer
	)

	log('----------------------------------------------------')
	log('Setting up the certificate owner...')

	const transferCalculatorOwnershipTx =
		await calculatorContract.transferOwnership(CarbonContract.address)

	await transferCalculatorOwnershipTx.wait(1)

	log('Carbon contract is the new owner of the calculator contract.')
	log('\n')
}

export default deployCarbon
deployCarbon.tags = ['all', 'Carbon']
