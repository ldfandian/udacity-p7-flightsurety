# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

* 1. For OS environment, you can find my Docker file at [Docker File](./.devcontainer/Dockerfile) ; Please take a look to see the basic package dependency.
* 2. To install, download or clone the repo, then:
```bash
root@aac05338eec7:/mnt/devroot/src/udacity-p7-flightsurety# truffle version
Truffle v5.0.2 (core: 5.0.2)
Solidity - ^0.4.24 (solc-js)
Node v10.24.1

root@aac05338eec7:/mnt/devroot/src/udacity-p7-flightsurety# npm install
...

root@aac05338eec7:/mnt/devroot/src/udacity-p7-flightsurety# truffle compile --all
...

root@aac05338eec7:/mnt/devroot/src/udacity-p7-flightsurety# truffle migrate
...

```
* 3. Pleae make sure you have at least 50+ accounts in your local ganache-cli blockchain. Also, I recommend that you have 1000 ethers for each local account, coz every airline registration takes 10 ethers.

## Develop Client

* To use the dapp:

`npm run dapp`

* To view dapp:

`http://localhost:8000`

## Develop Server

* To run oracles:

`npm run server`

## About Test

* dapp client: the project mainly depends on dapp client to do manual test. please enjoy.
** the screenshot of the dapp run is put at [runlog](./runlog/screenshot-localhost_8000-2021.08.28-00_32_20.png)

* truffle test: you can run it, all test cases can pass, but test coverage is not good enough.
** the run log of the truffle test is also put at [runlog](./runlog/truffle-test.log)

## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)