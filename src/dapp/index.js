import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

function displayGeneralInfo(contract) {
    contract.isOperational((error, result) => {
        console.log(error, result);
        let results = [];
        results.push({ label: 'Operational Status', error: error, value: result });
        results.push({ label: 'Current User', value: contract.owner })
        display('display-wrapper-general', 'General Status', 'Check if contract is operational', results);
        console.log(`displayGeneralInfo.callback: ${JSON.stringify(results)}`);
    });
}

function displayAirlineInfo(contract) {
    let results = [];
    let countAirlines = contract.airlines.count;
    results.push({ label: 'count of airlines', value: countAirlines});

    for (let i=0; i<countAirlines; i++) {
        let airline = contract.airlines.data[i];
        let message = `${airline.airline}, name='${airline.name}', isFunded=${airline.isFunded}`;
        if (airline.isFunded) {
            results.push({ label: `+ airline #${i}`, value: message});
        } else {
            results.push({ label: `- airline #${i}`, value: message});
        }
    }

    if (contract.airlines.pending != null) {
        let airline = contract.airlines.pending;
        let message = `${airline.airline}, name='${airline.name}', agree/votes=${airline.agree}/${airline.votes}`;
        results.push({ label: `? pending airline`, value: message});
    } else {
        results.push({ label: `no pending airline`, value: ''});
    }

    display('display-wrapper-airline', 'Airline Management', 'Check the airline status', results);
}

function formatFlightTime(flightTime) {
    let time = new Date(Number(flightTime)*1000);
    let timeStr = `${time.getFullYear()}-${time.getMonth()+1}-${time.getDate()} ${time.getHours()}:${time.getMinutes()}`;
    return timeStr;
}

function formatShortAddress(address) {
    return address.slice(0, 6) + '...' + address.slice(-4);
}

function formatFlightInfo(airline, airlineName, flight, flightTimestamp) {
    let airlineShort = formatShortAddress(airline);
    let timeStr = formatFlightTime(flightTimestamp);
    let message = `[${airlineName}('${airlineShort}'), ${flight}, ${timeStr}]`;
    return message;
}

function displayFlightInfo(contract) {
    let results = [];
    let countFlights = contract.flights.count;
    results.push({ label: 'count of flights', value: countFlights});

    for (let i=0; i<countFlights; i++) {
        let flight = contract.flights.data[i];
        let message = formatFlightInfo(flight.airline, flight.airlineName, flight.flight, flight.flightTimestamp)
                        + ` => status=${flight.statusCode}`;
        results.push({ label: `flight #${i}`, value: message});
    }

    display('display-wrapper-flight', 'Flight Management', 'Check the flight status', results);
}

function getFlightIndex(contract, airline, flight, flightTimestamp) {
    let countFlights = contract.flights.count;
    for (let i=0; i<countFlights; i++) {
        let one = contract.flights.data[i];
        if ((one.airline == airline) && (one.flight == flight) && (one.flightTimestamp == flightTimestamp)) {
            return i;
        }
    }
    return undefined;
}


function fillOptionsPassengerList(contract, elid) {
    let countPassengers = contract.passengers.length;
    let displayDiv = DOM.elid(elid);
    displayDiv.replaceChildren();
    for (let i=0; i<countPassengers; i++) {
        let passenger = contract.passengers[i];
        let shortAddr = formatShortAddress(passenger);
        let message = `passenger #${i}: ${shortAddr}`;
        displayDiv.appendChild(DOM.makeElement(`option`, { value: passenger }, message));
    }
}

function displayPassengerInfo(contract) {
    let results = [];

    results.push({ label: 'current passenger', value: contract.currentPassenger});
    results.push({ label: 'balance', value: contract.currentInsurances.balance});

    let countInsurances = contract.currentInsurances.count;
    results.push({ label: 'count of insurances', value: countInsurances });
    for (let i=0; i<countInsurances; i++) {
        let insurance = contract.currentInsurances.data[i];
        let message = formatFlightInfo(insurance.airline, insurance.airlineName, insurance.flight, insurance.flightTimestamp)
                        + ` => fund=${insurance.insuranceFund}, payback=${insurance.insurancePayback}`;
        let flightIndex = getFlightIndex(contract, insurance.airline, insurance.flight, insurance.flightTimestamp);
        let label = `insurance`;
        if (flightIndex != undefined) {
            let statusCode = contract.flights.data[flightIndex].statusCode;
            message = `Flight #${flightIndex}: ${message}, flight status=${statusCode}`;
            if (statusCode == 20) {
                label = '($) ' + label;
            }
        } else {
            message = `Flight N/A: ` + message;
        }
        results.push({ label: label, value: message});
    }

    display('display-wrapper-passenger', 'Passenger Operation', 'Check the passenger status', results);
}

(async() => {

    let contract = new Contract('localhost', async () => {

        // Overall status
        displayGeneralInfo(contract);
        DOM.elid('refresh-general').addEventListener('click', async () => {
            displayGeneralInfo(contract);
        });
        DOM.elid('init-test-data').addEventListener('click', async () => {
            let isCleanEnv = await contract.initializeTestData();
            if (!isCleanEnv) {
                displayError("Don't do it, it is not a clean environment.")
                return;
            }

            // reload general info
            displayGeneralInfo(contract);

            // reload airline info
            await contract.reloadAirlines();
            displayAirlineInfo(contract);

            // reload flight info
            await contract.reloadFlights();
            displayFlightInfo(contract);
        });

        // Airline status
        displayAirlineInfo(contract);
        DOM.elid('refresh-airlines').addEventListener('click', async () => {
            await contract.reloadAirlines();
            displayAirlineInfo(contract);
        });
        let reloadAirlineCallback = async (error, result) => {
            console.log(error, result);
            if (error) {
                displayError(error);
            } else {
                await contract.reloadAirlines();
                displayAirlineInfo(contract);
            }
        };
        DOM.elid('register-airline').addEventListener('click', () => {
            let address = DOM.elid('register-airline-address').value;
            let name = DOM.elid('register-airline-name').value;
            let from = DOM.elid('airline-caller-from').value;

            contract.registerAirline(address, name, from, reloadAirlineCallback);
        });
        DOM.elid('fund-airline').addEventListener('click', () => {
            let address = DOM.elid('fund-airline-address').value;
            let from = DOM.elid('airline-caller-from').value;

            contract.fundAirline(address, from, reloadAirlineCallback);
        });
        DOM.elid('approve-airline').addEventListener('click', () => {
            let address = DOM.elid('approve-airline-address').value;
            let code = DOM.elid('approve-airline-code').value;
            let from = DOM.elid('airline-caller-from').value;

            contract.approveAirline(address, code, from, reloadAirlineCallback);
        });

        // Flight management
        displayFlightInfo(contract);
        DOM.elid('refresh-flights').addEventListener('click', async () => {
            await contract.reloadFlights();
            displayFlightInfo(contract);
        });
        DOM.elid('register-flight').addEventListener('click', () => {
            let address = DOM.elid('register-flight-airline').value;
            let flight = DOM.elid('register-flight-flight').value;
            let timestamp = contract.getFutureTime(12);
            let from = DOM.elid('flight-caller-from').value;

            contract.registerFlight(address, flight, timestamp, from, async (error, result) => {
                console.log(error, result);
                if (error) {
                    displayError(error);
                } else {
                    await contract.reloadFlights();
                    displayFlightInfo(contract);
                }
            });
        });

        // Passenger transaction
        fillOptionsPassengerList(contract, 'passenger-caller-from');
        displayPassengerInfo(contract);
        DOM.elid('refresh-passenger').addEventListener('click', async () => {
            await contract.reloadFlights();
            await contract.reloadPassengerInfo();
            displayPassengerInfo(contract);
        });
        DOM.elid('passenger-change-to').addEventListener('click', async () => {
            // update contract
            let changeTo = DOM.elid('passenger-caller-from').value;
            if (changeTo) {
                contract.currentPassenger = changeTo;
            }
            // reload insurance info
            await contract.reloadPassengerInfo();
            displayPassengerInfo(contract);
        });
        let reloadPassengerCallback = async (error, result) => {
            console.log(error, result);
            if (error) {
                displayError(error);
            } else {
                await contract.reloadPassengerInfo();
                displayPassengerInfo(contract);
            }
        };
        DOM.elid('passenger-buy-insurance').addEventListener('click', () => {
            let flight = getFlightByInputElid(contract, 'buy-insurance-flight-index');
            if (!flight) {
                displayError(`flight index is invalid. accept range: [0-${contract.flights.count})`);
                return;
            }
            let payAmount = DOM.elid('buy-insurance-pay-amount').value;
            if (!payAmount) {
                displayError('please give an insurance payment');
                return;
            }

            // let's do it
            contract.buyInsurance(flight.airline, flight.flight, flight.flightTimestamp, payAmount, reloadPassengerCallback);
        });
        DOM.elid('fetch-flight-status').addEventListener('click', () => {
            let flight = getFlightByInputElid(contract, 'fetch-status-flight-index');
            if (!flight) {
                displayError(`flight index is invalid. accept range: [0-${contract.flights.count})`);
                return;
            }

            // let's do it
            contract.fetchFlightStatus(flight.airline, flight.flight, flight.flightTimestamp, reloadPassengerCallback);
        });
        DOM.elid('claim-flight-refund').addEventListener('click', () => {
            let flight = getFlightByInputElid(contract, 'claim-refund-flight-index');
            if (!flight) {
                displayError(`flight index is invalid. accept range: [0-${contract.flights.count})`);
                return;
            }

            // let's do it
            contract.claimInsurancePayback(flight.airline, flight.flight, flight.flightTimestamp, reloadPassengerCallback);
        });
        DOM.elid('passenger-withdraw-fund').addEventListener('click', () => {
            let payAmount = DOM.elid('passenger-withdraw-amount').value;
            if (!payAmount) {
                displayError('please give an withdraw amount');
                return;
            }

            // let's do it
            contract.passengerWithdraw(payAmount, reloadPassengerCallback);
        });
    });

})();

function getFlightByInputElid(contract, elid) {
    let flightIndex = DOM.elid(elid).value;
    if (flightIndex) {
        flightIndex = Number(flightIndex);
    }
    if ((flightIndex < 0) || (flightIndex >= contract.flights.count)) {
        return undefined;
    }

    // let's do it
    return contract.flights.data[flightIndex];
}

function display(container, title, description, results) {
    let displayDiv = DOM.elid(container);
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.replaceChildren(section);
}

function displayError(error) {
    alert(error);
}
