require('dotenv').config();
const ethers = require('ethers');
const airnodeAbi = require('@api3/airnode-abi');
const evm = require('../src/evm');
const util = require('../src/util');
const parameters = require('../src/parameters');

/// Global variable
let BITCOIN_PRICE


///-----------
/// Executor
///-----------
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

async function main() {
    console.log('-------------- Make request via API3 --------------')
    await api3Request()

    console.log('-------------- Workflow of lending/borrowing --------------')
    await fundWBTC()
    await lendDAI()
    await borrowWBTC()
    await repayWBTC()
    await withdrawDAI()
}


///-------------------------------------
/// Request price data via API3 oracle
///-------------------------------------
async function api3Request() {
    const coinId = 'bitcoin';     /// [Note]: BTC price  (e.g. bitcoin price is 35548 USD)
    //const coinId = 'dai';       /// [Note]: DAI price  (e.g. dai price is 1 USD)
    //const coinId = 'ethereum';  /// [Note]: ETH price  (e.g. ethereum price is 2633 USD)
    const wallet = await evm.getWallet();
    const exampleClient = new ethers.Contract(
        util.readFromLogJson('ExampleClient address'),
        evm.ExampleClientArtifact.abi,
        wallet
    );
    const airnode = await evm.getAirnode();

    console.log('Making the request...');
    async function makeRequest() {
        const receipt = await exampleClient.makeRequest(
            parameters.providerId,
            parameters.endpointId,
            util.readFromLogJson('Requester index'),
            util.readFromLogJson('Designated wallet address'),
            airnodeAbi.encode([{ name: 'coinId', type: 'bytes32', value: coinId }])
        );
        return new Promise((resolve) =>
            wallet.provider.once(receipt.hash, (tx) => {
                const parsedLog = airnode.interface.parseLog(tx.logs[0]);
                resolve(parsedLog.args.requestId);
            })
        );
    }
    const requestId = await makeRequest();
    console.log(`Made the request with ID ${requestId}.\nWaiting for it to be fulfilled...`);

    function fulfilled(requestId) {
        return new Promise((resolve) =>
            wallet.provider.once(airnode.filters.ClientRequestFulfilled(null, requestId), resolve)
        );
    }
    await fulfilled(requestId);
    console.log('Request fulfilled');
    console.log(`${coinId} price is ${(await exampleClient.fulfilledData(requestId)) / 1e6} USD`);

    /// Assign Bitcoin price which is retrieved via API3 oracle above
    BITCOIN_PRICE = await exampleClient.fulfilledData(requestId) / 1e6
    console.log('=== BITCOIN_PRICE ===', String(BITCOIN_PRICE))
}


///---------------------------
/// Workflow of the CDP.sol
///---------------------------

async function fundWBTC() {
    console.log('fundWBTC()')
    /// [Todo]:
}

async function lendDAI() {
    console.log('lendDAI()')
}

async function borrowWBTC() {
    console.log('borrowWBTC()')
}

async function repayWBTC() {
    console.log('repayWBTC()')
}

async function withdrawDAI() {
    console.log('withdrawDAI()')
}
