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
        this.flights = new Object({ count: 0, data: [] });
        this.passengers = [];
    }

    initialize(callback) {
        let self = this;
        this.web3.eth.getAccounts(async (error, accts) => {
            this.owner = accts[0];
            console.log(`owner=${this.owner}`);

            await self.reloadAirlines();
            await self.reloadFlights();

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
        console.log(`getApiCaller: uses '${callerFrom}'`);
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

    async reloadFlights() {
        let flightInfo = new Object({
            count: 0,
            data: [],
        });

        // get the list of registered airlines
        flightInfo.count = await this.flightSuretyApp.methods.getFlightCount().call({ from: this.owner });
        if (flightInfo.count > 0) {
            for (let i=0; i<flightInfo.count; i++) {
                let result = await this.flightSuretyApp.methods.getFlightInfomation(i).call({ from: this.owner });
                let flight = {
                    airline: result.airline,
                    airlineName: result.airlineName,
                    airlineFunded: result.airlineFunded,
                    flight: result.flight,
                    flightTimestamp: result.flightTimestamp,
                    statusCode: result.statusCode,
                };
                flightInfo.data.push(flight);
            }
        }

        console.log(`reloadFlights: ${JSON.stringify(flightInfo)}`);
        this.flights = flightInfo;
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
        console.log(`fundAirline: airline=${airline}`);
    }

    approveAirline(airline, code, from, callback) {
        let caller = this.getApiCaller(from);
        this.flightSuretyApp.methods
            .approveAirline(airline, code)
            .send({ from: caller, gas: 1000000 }, callback);
        console.log(`approveAirline: airline=${airline}, code=${code}`);
    }

    registerFlight(airline, flight, timestamp, from, callback) {
        let caller = this.getApiCaller(from);
        this.flightSuretyApp.methods
            .registerFlight(airline, flight, timestamp)
            .send({ from: caller, gas: 1000000 }, callback);
        console.log(`registerFlight: airline=${airline}, flight=${flight}, timestamp=${timestamp}`);
    }
}