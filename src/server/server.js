import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

require("babel-polyfill");

// global variables
let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

const TEST_ORACLE_COUNT = 20;
const TEST_ORACLE_ACCOUNT_START_INDEX = 20;

let oracleAddrToIndexes = new Map();

// get oracle's account
function getOracleAccount(accounts, index) {
  if (index >= accounts.length) {
    throw "need more oracle accounts";
  }

  let result = accounts[index];
  return result;
}

// init the oracle server
(async() => {
  let accounts = await web3.eth.getAccounts();
  web3.eth.defaultAccount = accounts[0];     // initialize default account

  // let's register all oracles
  let fee = await flightSuretyApp.methods.ORACLE_REGISTRATION_FEE().call();
  for(let index=0; index<TEST_ORACLE_COUNT; index++) {
    // register the oracle
    let account = getOracleAccount(accounts, TEST_ORACLE_ACCOUNT_START_INDEX+index);
    await flightSuretyApp.methods.registerOracle().send({ from: account, value: fee, gas: 2000000 });

    // retrieve the indexes
    let indexes = await flightSuretyApp.methods.getMyIndexes().call({ from: account });
    console.log(`Oracle ${index}('${account}')'s Index: ${indexes[0]}, ${indexes[1]}, ${indexes[2]}`)

    // store the oracle info
    oracleAddrToIndexes[account.address] = indexes;
  }

  // TODO
})();

// handle the oracle event
flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
});

// prepare the dummy http server
const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


