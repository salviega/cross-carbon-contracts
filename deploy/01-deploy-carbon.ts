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

	const args: any[] = [
		'0x996b39698CF96A70B7a7005B5d1924a66C5E8f0e', // _TCO2Faucet
		'0xa5831eb637dff307395b5183c86B04c69C518681', // _TCO2Token
		'0x050Ca75E3957c37dDF26D58046d8F9967B88190c', // _EPNS_COMM_ADDRESS
		'Carbon', //_name
		'CARBON', // _symbol
		certificateArgs // _certificateArgs
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

	const certificateAddress: string =
		await carbonContract.CARBON_CERTIFICATE_ADDRESS()

	const certificateContract: Contract = await ethers.getContractAt(
		'Certificate',
		deployer
	)

	const transferOwnershipTx = await certificateContract.transferOwnership(
		CarbonContract.address
	)

	await transferOwnershipTx.wait(1)

	log('\n')
	log('Carbon contract is the new owner of the certificate contract.')
}

export default deployCarbon
deployCarbon.tags = ['all', 'Carbon']
