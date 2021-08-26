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

// utils func to get oracle's account address
function getOracleAccount(accounts, index) {
  if (index >= accounts.length) {
    throw "need more oracle accounts";
  }
  let result = accounts[index];
  return result;
}

// utils func to check if an oracle match the specified index
function matchOracleIndexes(oracleAddress, messageIndex) {
  let oracleInfo = oracleAddrToIndexes[oracleAddress];
  let contractIndexes = oracleInfo.contractIndexes;

  let match = (contractIndexes[0] == messageIndex) || (contractIndexes[1] == messageIndex) || (contractIndexes[2] == messageIndex);
  return match;
}

// init the oracle server
(async() => {
  let accounts = await web3.eth.getAccounts();
  web3.eth.defaultAccount = accounts[0];     // initialize default account

  console.log("Registering orcales and getting contract indexes...");

  // let's register all oracles
  let fee = await flightSuretyApp.methods.ORACLE_REGISTRATION_FEE().call();
  for(let index=0; index<TEST_ORACLE_COUNT; index++) {
    // register the oracle
    let account = getOracleAccount(accounts, TEST_ORACLE_ACCOUNT_START_INDEX+index);
    await flightSuretyApp.methods.registerOracle().send({ from: account, value: fee, gas: 2000000 });

    // retrieve the indexes
    let indexes = await flightSuretyApp.methods.getMyIndexes().call({ from: account });
    console.log(`Registered oracle ${index}('${account}'): indexes: ${indexes[0]}, ${indexes[1]}, ${indexes[2]}`)

    // store the oracle info
    oracleAddrToIndexes[account] = {
      index: index,
      address: account,
      contractIndexes: indexes
    }
  }
})();

// handle the OracleRequest event
flightSuretyApp.events.OracleRequest({ fromBlock: 0 }, function (error, event) {
  if (error) {
    console.log(`Found OracleRequest error: ${error}`);
    return;
  }

  console.log(`Found OracleRequest event: ${event}`)

  // let's generate a random status code among (10, 20, 30, 40, 50)
  //   Note: Flight status codees
  //     uint8 private constant STATUS_CODE_ON_TIME = 10;
  //     uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
  //     uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
  //     uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
  //     uint8 private constant STATUS_CODE_LATE_OTHER = 50;
  let randomStatusCode = Math.floor((Math.random() * 5) + 1) * 10;

  // event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);
  let targetIndex = event.returnValues.index;
  let targetAirline = event.returnValues.airline;
  let targetFlight = event.returnValues.flight;
  let targetTimestamp = event.returnValues.timestamp;

  // let each oracle to handle the request
  oracleAddrToIndexes.forEach((value, key, map) => {
    let oracleAddress = key;
    let oracleInfo = value;

    // check if the target index match the oracle's indexes
    if (matchOracleIndexes(oracleAddress, targetIndex)) {
      // submit the request to the app contract
      flightSuretyApp.methods
        .submitOracleResponse(targetIndex, targetAirline, targetFlight, targetTimestamp, randomStatusCode)
        .send({ from: oracleAddress, gas: 4000000 })
        .then(res => {
          console.log(`Oracle ${oracleInfo.index}('${oracleAddress}') submit sc=${randomStatusCode} (index=${targetIndex}) successfully.`);
        })
        .catch(err => {
          console.log(`Oracle ${oracleInfo.index}('${oracleAddress}') submit sc=${randomStatusCode} (index=${targetIndex}) failed. Error: ${err}`);
        });
    }
  })
})

// handle the FlightStatusInfo event
flightSuretyApp.events.FlightStatusInfo(function (error, event) {
  if (error) {
    console.log(`Found FlightStatusInfo error: ${error}`);
    return;
  }

  console.log(`Found FlightStatusInfo event: airline='${event.airline}', flight='${event.flight}', timestamp=${event.timestamp}, statusCode=${event.statusCode}`);
})

// prepare the dummy http server
const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


