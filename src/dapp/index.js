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
    try {
        let countAirlines = contract.airlines.count;
        results.push({ label: '# of airlines', value: countAirlines});
        if (countAirlines > 0) {
            for (let i=0; i<countAirlines; i++) {
                let airline = contract.airlines.data[i];
                let message = `${airline.airline}, name='${airline.name}', isFunded=${airline.isFunded}`;
                if (airline.isFunded) {
                    results.push({ label: `+ airline ${i}`, value: message});
                } else {
                    results.push({ label: `- airline ${i}`, value: message});
                }
            }
        }

        if (contract.airlines.pending != null) {
            let airline = contract.airlines.pending;
            let message = `${airline.airline}, name='${airline.name}', agree/votes=${airline.agree}/${airline.votes}`;
            results.push({ label: `? pending airline`, value: message});
        } else {
            results.push({ label: `no pending airline`, value: ''});
        }
    } catch (err) {
        results.push({ label: '# of airlines', error: err});
    }
    display('display-wrapper-airline', 'Airline Management', 'Check the airline status', results);
}

function formatFlightTime(flightTime) {
    let time = new Date(Number(flightTime)*1000);
    let timeStr = `${time.getFullYear()}-${time.getMonth()+1}-${time.getDate()} ${time.getHours()}:${time.getMinutes()}`;
    return timeStr;
}

function formatFlightInfo(flight) {
    let airlineShort = flight.airline.slice(0, 6) + '...' + flight.airline.slice(-4);
    let timeStr = formatFlightTime(flight.flightTimestamp);
    let message = `${flight.airlineName}('${airlineShort}'), ${flight.flight}, ${timeStr} => status=${flight.statusCode}`;
    return message;
}

function displayFlightInfo(contract) {
    let results = [];
    try {
        let countFlights = contract.flights.count;
        results.push({ label: '# of flights', value: countFlights});
        if (countFlights > 0) {
            for (let i=0; i<countFlights; i++) {
                let flight = contract.flights.data[i];
                let message = formatFlightInfo(flight);
                results.push({ label: `flight ${i}`, value: message});
                console.log(i);
            }
        }
    } catch (err) {
        results.push({ label: '# of flight', error: err});
    }
    display('display-wrapper-flight', 'Flight Management', 'Check the flight status', results);
}

(async() => {

    let contract = new Contract('localhost', async () => {

        // Overall status
        displayGeneralInfo(contract);
        DOM.elid('refresh-general').addEventListener('click', async () => {
            displayGeneralInfo(contract);
        });

        // Airline status
        displayAirlineInfo(contract);
        DOM.elid('refresh-airlines').addEventListener('click', async () => {
            await contract.reloadAirlines();
            displayAirlineInfo(contract);
        });
        DOM.elid('register-airline').addEventListener('click', () => {
            let address = DOM.elid('register-airline-address').value;
            let name = DOM.elid('register-airline-name').value;
            let from = DOM.elid('airline-caller-from').value;

            contract.registerAirline(address, name, from, async (error, result) => {
                console.log(error, result);
                if (error) {
                    displayError(error);
                } else {
                    await contract.reloadAirlines();
                    displayAirlineInfo(contract);
                }
            });
        });
        DOM.elid('fund-airline').addEventListener('click', () => {
            let address = DOM.elid('fund-airline-address').value;
            let from = DOM.elid('airline-caller-from').value;

            contract.fundAirline(address, from, async (error, result) => {
                console.log(error, result);
                if (error) {
                    displayError(error);
                } else {
                    await contract.reloadAirlines();
                    displayAirlineInfo(contract);
                }
            });
        });
        DOM.elid('approve-airline').addEventListener('click', () => {
            let address = DOM.elid('approve-airline-address').value;
            let code = DOM.elid('approve-airline-code').value;
            let from = DOM.elid('airline-caller-from').value;

            contract.approveAirline(address, code, from, async (error, result) => {
                console.log(error, result);
                if (error) {
                    displayError(error);
                } else {
                    await contract.reloadAirlines();
                    displayAirlineInfo(contract);
                }
            });
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
            let timestamp = new Date().getTime() / 1000;        // get current time (in second)
            timestamp -= (timestamp % (60*10));                 // round to 10 minute
            timestamp += 12*3600;                               // 12 hours later
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
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display("display-wrapper-passenger", 'Passenger Operation', 'Check the passenger\'s status', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })
        display("display-wrapper-passenger", 'Passenger Operation', 'Check the passenger\'s status', [ { label: 'Fetch Flight Status', value: 'TODO'} ]);
    
    });

})();


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

