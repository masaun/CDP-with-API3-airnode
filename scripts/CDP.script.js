require('dotenv').config()

/// Hardhat
const hre = require("hardhat")

const ethers = require('ethers')
const airnodeAbi = require('@api3/airnode-abi')
const evm = require('../src/evm')
const util = require('../src/util')
const parameters = require('../src/parameters')

/// Global variable
let BITCOIN_PRICE

/// Variable for assiging artifacts
let DAI
let WBTC
let CDP

/// Variable for assiging smart contract instance
let dai
let wbtc
let cdp

/// Variable for assiging deployed-addresses
let DAI_TOKEN
let WBTC_TOKEN
let CDP_ADDRESS


///-----------
/// Executor
///-----------
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

async function main() {
    console.log('\n-------------- Setup Wallets (Accounts) --------------')
    await setupWallets()

    console.log('\n-------------- Create smart contracts instances --------------')
    await deploySmartContracts()

    console.log('\n-------------- Make request via API3 airnode (oracle) --------------')
    await api3Request()

    console.log('\n-------------- Workflow of lending/borrowing --------------')
    await fundWBTC()
    await lendDAI()
    await getLend()
    await borrowWBTC()
    await getRepaymentAmount()
    await repayWBTC()
    await withdrawDAI()
}

async function setupWallets() {
    user = process.env.DEPLOYER_ADDRESS
    console.log("=== user ===", user)
}


///--------------------------------------------------------------
/// Deploy smart contracts instances and create their instances 
///--------------------------------------------------------------
async function deploySmartContracts() {
    DAI = await hre.ethers.getContractFactory("DAI")
    WBTC = await hre.ethers.getContractFactory("WBTC")
    CDP = await hre.ethers.getContractFactory("CDP")

    console.log("Deploy the DAI contract")
    dai = await DAI.deploy()
    DAI_TOKEN = dai.address

    console.log("Deploy the WBTC contract")
    wbtc = await WBTC.deploy()
    WBTC_TOKEN = wbtc.address

    console.log("Deploy the CDP contract")
    cdp = await CDP.deploy(DAI_TOKEN, WBTC_TOKEN)
    CDP_ADDRESS = cdp.address
    //await cdp.deployed()

    console.log("=== DAI ===", DAI_TOKEN)
    console.log("=== WBTC ===", WBTC_TOKEN)
    console.log("=== CDP ===", CDP_ADDRESS)
}


///-------------------------------------
/// Request price data via API3 oracle
///-------------------------------------
async function api3Request() {
    const coinId = 'bitcoin'     /// [Note]: BTC price  (e.g. bitcoin price is 35548 USD)
    //const coinId = 'dai'       /// [Note]: DAI price  (e.g. dai price is 1 USD)
    //const coinId = 'ethereum'  /// [Note]: ETH price  (e.g. ethereum price is 2633 USD)
    const wallet = await evm.getWallet()
    const exampleClient = new ethers.Contract(
        util.readFromLogJson('ExampleClient address'),
        evm.ExampleClientArtifact.abi,
        wallet
    )
    const airnode = await evm.getAirnode()

    console.log('Making the request...')
    async function makeRequest() {
        const receipt = await exampleClient.makeRequest(
            parameters.providerId,
            parameters.endpointId,
            util.readFromLogJson('Requester index'),
            util.readFromLogJson('Designated wallet address'),
            airnodeAbi.encode([{ name: 'coinId', type: 'bytes32', value: coinId }])
        )
        return new Promise((resolve) =>
            wallet.provider.once(receipt.hash, (tx) => {
                const parsedLog = airnode.interface.parseLog(tx.logs[0])
                resolve(parsedLog.args.requestId)
            })
        )
    }
    const requestId = await makeRequest()
    console.log(`Made the request with ID ${requestId}.\nWaiting for it to be fulfilled...`)

    function fulfilled(requestId) {
        return new Promise((resolve) =>
            wallet.provider.once(airnode.filters.ClientRequestFulfilled(null, requestId), resolve)
        )
    }
    await fulfilled(requestId)
    console.log('Request fulfilled')
    console.log('Retrieve current BTC price')
    console.log(`${coinId} price is ${(await exampleClient.fulfilledData(requestId)) / 1e6} USD`)

    /// Assign Bitcoin price which is retrieved via API3 oracle above
    BITCOIN_PRICE = await exampleClient.fulfilledData(requestId) / 1e6
    console.log('=== BITCOIN_PRICE ===', String(BITCOIN_PRICE))
}


///---------------------------
/// Workflow of the CDP.sol
///---------------------------

async function fundWBTC() {
    console.log('fundWBTC()')
    const fundWBTCAmount = 100  /// 100 WBTC - [Todo]: Add toWei() by ether.js
    let txReceipt1 = await wbtc.approve(CDP_ADDRESS, fundWBTCAmount)
    let txReceipt2 = await cdp.fundWBTC(fundWBTCAmount)
}

async function lendDAI() {
    console.log('lendDAI()')
    const daiAmount = 1000000     /// 1,000,000 DAI - [Todo]: Add toWei() by ether.js
    let txReceipt1 = await dai.approve(CDP_ADDRESS, daiAmount)
    let txReceipt2 = await cdp.lendDAI(daiAmount)
}

async function getLend() {
    console.log('getLend()')
    const lendId = 1
    let lend = await cdp.getLend(lendId)
    let _daiAmountLended = String(await lend.daiAmountLended)
    console.log('=== daiAmountLended ===', _daiAmountLended)
}

async function borrowWBTC() {
    console.log('borrowWBTC()')
    const lendId = 1
    const btcPrice = BITCOIN_PRICE  /// This BTC price is retrieved by API3 oracle
    //const btcPrice = 34054        /// [Test]: 1 BTC == 34,054 USD
    const borrowWBTCAmount = 10     /// 10 WBTC - [Todo]: Add toWei() by ether.js
    let txReceipt1 = await wbtc.approve(CDP_ADDRESS, borrowWBTCAmount)
    let txReceipt2 = await cdp.borrowWBTC(lendId, btcPrice, borrowWBTCAmount)
}

async function getRepaymentAmount() {
    console.log('getRepaymentAmount()')
    const borrowId = 1
    let repaymentAmount = await cdp.getRepaymentAmount(borrowId)
    console.log('=== repaymentAmount ===', String(repaymentAmount))
}

async function repayWBTC() {
    console.log('repayWBTC()')
    const borrowId = 1
    let repaymentAmount = await cdp.getRepaymentAmount(borrowId)
    let txReceipt = await cdp.repayWBTC(borrowId, repaymentAmount)
}

async function withdrawDAI() {
    console.log('withdrawDAI()')
    const lendId = 1
    const withdrawalAmount = 1000000  /// 1,000,000 DAI
    let txReceipt = await cdp.withdrawDAI(lendId, withdrawalAmount)
}
