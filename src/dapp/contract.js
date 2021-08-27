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
        this.airlineNameMap = new Map();
        this.flights = new Object({ count: 0, data: [] });
        this.passengers = [];
        this.currentPassenger = null;
        this.currentInsurances = new Object({ count: 0, balance: 0, data: [] });

        // use [0-6) accounts as the test airline
        // use [15-20) accounts as the test passengers
        // use [20-40) accounts as the test oracles
        this.accounts = [];
    }

    initialize(callback) {
        let self = this;
        this.web3.eth.getAccounts(async (error, accts) => {
            if (accts.length < 40) {
                throw "need more than 40 test accounts for the test dapp to run"
            }

            this.owner = accts[0];
            console.log(`owner=${this.owner}`);

            this.accounts = accts;
            self.initializePassengerAccount();

            await self.reloadAirlines();
            await self.reloadFlights();
            await self.reloadPassengerInfo();

            callback();
        });
    }

    initializePassengerAccount() {
        // use [15-20) accounts as the test passengers
        this.passengers = this.accounts.slice(15, 20);
        this.currentPassenger = this.passengers[0];
    }

    async initializeTestData() {
        // Both of the following conditions meet, we think it is a good clean environment:
        //   1. a clean environment has only 1 airline;
        //   2. a clean environment has no flight;
        let isCleanEnv = (this.airlines.count <= 1) && (this.flights.count <= 0);
        if (isCleanEnv) {
            try
            {
                // parpare airlines
                // use [0-6) accounts as the test airline
                await this.fundAirline(this.accounts[0], this.owner, console.log);
                await this.registerAirline(this.accounts[1], 'China East Airline', this.owner, console.log);     // pass registration
                await this.registerAirline(this.accounts[2], 'China South Airline', this.owner, console.log);    // pass registration
                await this.registerAirline(this.accounts[3], 'China West Airline', this.owner, console.log);     // pass registration
                await this.registerAirline(this.accounts[4], 'China North Airline', this.owner, console.log);    // wait for approval
                await this.fundAirline(this.accounts[1], this.accounts[1], console.log);
                await this.fundAirline(this.accounts[2], this.accounts[2], console.log);

                // prepar flights
                await this.registerFlight(this.accounts[1], 'Beijing->Shanghai', this.getFutureTime(12), this.accounts[1], console.log);
                await this.registerFlight(this.accounts[2], 'Beijing->Tianjin', this.getFutureTime(8), this.accounts[2], console.log);
                await this.registerFlight(this.accounts[1], 'Tianjin->Wuhan', this.getFutureTime(6), this.accounts[1], console.log);
                await this.registerFlight(this.accounts[2], 'Beijing->Datong', this.getFutureTime(24), this.accounts[2], console.log);
            } catch (error) {
                alert(error);
            }
        }

        return isCleanEnv;
    }

    getFutureTime(hours) {
        let timestamp = new Date().getTime() / 1000;            // get current time (in second)
        timestamp -= (timestamp % (60*10));                     // round to 10 minute
        timestamp += hours*3600;                                // ? hours later
        return timestamp;
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
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
        let airlineInfoNameMap = new Map();

        // get the list of registered airlines
        airlineInfo.count = await this.flightSuretyApp.methods.countOfAirlines().call({ from: this.owner });
        for (let i=0; i<airlineInfo.count; i++) {
            let result = await this.flightSuretyApp.methods.getAirlineInfoByIndex(i).call({ from: this.owner });
            let airline = {
                airline: result.airline,
                name: result.name,
                isFunded: result.isFunded,
            };
            airlineInfo.data.push(airline);
            airlineInfoNameMap.set(String(result.airline), result.name);
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
            airlineInfoNameMap.set(String(result.airline), result.name);
        }

        console.log(`reloadAirlines: ${JSON.stringify(airlineInfo)}`);
        this.airlines = airlineInfo;
        this.airlineNameMap = airlineInfoNameMap;
    }

    getAirlineName(address) {
        let result = '<unknown>';
        let key = String(address);
        if (this.airlineNameMap.has(key)) {
            result = this.airlineNameMap.get(key);
        }
        return result;
    }

    async reloadFlights() {
        let flightInfo = new Object({
            count: 0,
            data: [],
        });

        // get the list of registered airlines
        flightInfo.count = await this.flightSuretyApp.methods.getFlightCount().call({ from: this.owner });
        for (let i=0; i<flightInfo.count; i++) {
            let result = await this.flightSuretyApp.methods.getFlightInfoByIndex(i).call({ from: this.owner });
            let airlineName = this.getAirlineName(result.airline);
            let flight = {
                airline: result.airline,
                airlineName: airlineName,
                flight: result.flight,
                flightTimestamp: result.flightTimestamp,
                statusCode: result.statusCode,
            };
            flightInfo.data.push(flight);
        }

        console.log(`reloadFlights: ${JSON.stringify(flightInfo)}`);
        this.flights = flightInfo;
    }

    async reloadPassengerInfo() {
        if (!this.currentPassenger) {
            console.log(`reloadPassengerInfo: no current passenger`);
            return;
        }

        let insurances = new Object({
            count: 0,
            balance: 0,
            data: [],
        });

        // load insurance count and passenger balance
        let info = await this.flightSuretyApp.methods.getPassengerInsurances().call({ from: this.currentPassenger });
        insurances.count = info.count;
        insurances.balance = info.balance;

        // load each insurance
        for (let i=0; i<insurances.count; i++) {
            let result = await this.flightSuretyApp.methods.getPassengerInsuranceByIndex(i).call({ from: this.currentPassenger });
            let airlineName = this.getAirlineName(result.airline);
            let insurance = {
                airline: result.airline,
                airlineName: airlineName,
                flight: result.flight,
                flightTimestamp: result.flightTimestamp,
                insuranceFund: result.insuranceFund,
                insurancePayback: result.insurancePayback,
            };
            insurances.data.push(insurance);
        }

        this.currentInsurances = insurances;
        console.log(`reloadPassengerInfo: ${JSON.stringify(insurances)}`);
    }

    registerAirline(airline, name, from, callback) {
        let caller = this.getApiCaller(from);
        let promise = this.flightSuretyApp.methods
            .registerAirline(airline, name)
            .send({ from: caller, gas: 1000000 }, callback);
        console.log(`registerAirline: airline=${airline}, name=${name}`);
        return promise;
    }

    fundAirline(airline, from, callback) {
        let fund = Web3.utils.toWei("1", "ether");
        let caller = this.getApiCaller(from);
        let promise = this.flightSuretyApp.methods
            .fundAirline(airline)
            .send({ from: caller, value: fund }, callback);
        console.log(`fundAirline: airline=${airline}`);
        return promise;
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
        let promise = this.flightSuretyApp.methods
            .registerFlight(airline, flight, timestamp)
            .send({ from: caller, gas: 1000000 }, callback);
        console.log(`registerFlight: airline=${airline}, flight=${flight}, timestamp=${timestamp}`);
        return promise;
    }

    buyInsurance(airline, flight, timestamp, amount, callback) {
        let caller = this.currentPassenger;
        let fund = Web3.utils.toWei(amount, "ether");
        this.flightSuretyApp.methods
            .buyInsurance(caller, airline, flight, timestamp)
            .send({ from: caller, value: fund, gas: 1000000 }, callback);
        console.log(`buyInsurance: airline=${airline}, flight=${flight}, timestamp=${timestamp}, value=${fund} wei`);
    }

    fetchFlightStatus(airline, flight, timestamp, callback) {
        let caller = this.currentPassenger;
        this.flightSuretyApp.methods
            .fetchFlightStatus(airline, flight, timestamp)
            .send({ from: caller, gas: 1000000 }, callback);
        console.log(`fetchFlightStatus: airline=${airline}, flight=${flight}, timestamp=${timestamp}`);
    }
}