import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = new Object({ count: 0, data: [], pending: null });
        this.passengers = [];
    }

    initialize(callback) {
        let self = this;
        this.web3.eth.getAccounts(async (error, accts) => {
            this.owner = accts[0];
            console.log(`owner=${this.owner}`);

            await self.reloadAirlines(null);

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    getApiCaller(from) {
        let callerFrom = this.owner;
        if (from) {
            callerFrom = from;
        }
        return callerFrom;
    }

    async reloadAirlines() {
        let airlineInfo = new Object({
            count: 0,
            data: [],
            pending: null,
        });

        // get the list of registered airlines
        airlineInfo.count = await this.flightSuretyApp.methods.countOfAirlines().call({ from: this.owner });
        if (airlineInfo.count > 0) {
            for (let i=0; i<airlineInfo.count; i++) {
                let result = await this.flightSuretyApp.methods.getAirlineInfomationByIndex(i).call({ from: this.owner });
                let airline = {
                    airline: result.airline,
                    name: result.name,
                    isFunded: result.isFunded,
                };
                airlineInfo.data.push(airline);
            }
        }

        // get the pending airline, if any
        let result = await this.flightSuretyApp.methods.getAirlinePendingRequest().call({ from: this.owner });
        if(Number(result.count) > 0) {
            airlineInfo.pending = {
                airline: result.airline,
                name: result.name,
                votes: result.votes,
                agree: result.agree,
            };
        }

        console.log(`reloadAirlines: ${JSON.stringify(airlineInfo)}`);
        this.airlines = airlineInfo;
    }

    registerAirline(airline, name, from, callback) {
        let caller = this.getApiCaller(from);
        this.flightSuretyApp.methods
            .registerAirline(airline, name)
            .send({ from: caller, gas: 1000000 }, callback);
        console.log(`registerAirline: airline=${airline}, name=${name}`);
    }

    fundAirline(airline, from, callback) {
        let fund = Web3.utils.toWei("1", "ether");
        let caller = this.getApiCaller(from);
        this.flightSuretyApp.methods
            .fundAirline(airline)
            .send({ from: caller, value: fund }, callback);
    }

    approveAirline(airline, code, from, callback) {
        let caller = this.getApiCaller(from);
        this.flightSuretyApp.methods
            .approveAirline(airline, code)
            .send({ from: caller, gas: 1000000 }, callback);
    }
}