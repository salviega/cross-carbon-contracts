import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction, DeployResult } from 'hardhat-deploy/types'
import { developmentChains, networkConfig } from '../helper-hardhat-config'
import verify from '../helper-functions'
import { ethers } from 'hardhat'
import { Contract, ethers as ethersType } from 'ethers'
import {
	MUMBAI_CCIP_ROUTER,
	MUMBAI_EPNS_COMM_ADDRESS,
	MUMBAI_LINK_TOKEN,
	SEPOLIA_CHAIN_SELECTOR
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
	log('Deploying Mumbai Gateway contract and waiting for confirmations...')

	const args: any[] = [
		MUMBAI_CCIP_ROUTER, // _router
		MUMBAI_LINK_TOKEN, // _linkToken
		MUMBAI_EPNS_COMM_ADDRESS // _EPNS_COMM_ADDRESS
	]

	const GatewayContract: DeployResult = await deploy('Gateway', {
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
		await verify(GatewayContract.address, args)
	}

	const gatewayContract: Contract = await ethers.getContractAt(
		'Gateway',
		GatewayContract.address
	)

	const whitelistChainTx = await gatewayContract.whitelistChain(
		SEPOLIA_CHAIN_SELECTOR
	)
	await whitelistChainTx.wait(1)

	const LINK_DECIMALS = 18
	const LINK_AMOUNT = ethers.parseUnits('2', LINK_DECIMALS)

	const linkTokenContract: Contract = await ethers.getContractAt(
		IERC20ExtendedJson.abi,
		MUMBAI_LINK_TOKEN
	)

	log('----------------------------------------------------')
	log('Transferring 2 LINKs to the Gateway contract...')

	const transferLinkTx = await linkTokenContract.transfer(
		GatewayContract.address,
		LINK_AMOUNT
	)
	await transferLinkTx.wait(1)

	log('2 LINKs transferred to the Gateway contract.')
	log('\n')
}

export default deployCarbon
deployCarbon.tags = ['all', 'Carbon']
