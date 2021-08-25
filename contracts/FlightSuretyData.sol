pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping(address => uint256) private authorizedContracts;            // the authorizaed app contact's address

    /*****************************************************************
     * the following variable are passenger related
     ****************************************************************/

    mapping(address => uint256) private passengerCredits;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    string airlineName
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        _addAirline(msg.sender, msg.sender, airlineName);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the "authorized app contract" account to be the function caller
    */
    modifier requireIsCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized app contract");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizeContract
                            (
                                address contractAddress
                            )
                            external
                            requireIsOperational
                            requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract
                            (
                                address contractAddress
                            )
                            external
                            requireIsOperational
                            requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

// region AIRLINE MANAGEMENT

    /*****************************************************************
     * the following variable are airline related
     ****************************************************************/

    uint256 public constant FUND_FEE_AIRLINE = 10 ether;        // Fee to be paid when registering oracle

    struct Airline {
        bool isRegistered;
        string name;                                                    // name of the airline
        uint256 totalFund;                                              // total balance (in wei) that the airline has funded
    }

    uint public countOfAirlines = 0;                                    // count of the registered airlines
    mapping(address => Airline) private airlines;                       // all the registered airlines (excluding wait-for-approval airlines)

    event AirlineRegistered(address airline, address registrant, string name);              // the event to request other airlines to approve a new airline

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function isRegisteredAirline
                            (
                                address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return airlines[airline].isRegistered;
    }

    function _addAirline
                            (   
                                address airline,
                                address registrant,
                                string name
                            )
                            internal
    {
        require(airline != address(0), 'empty airline address');
        require(bytes(name).length > 0, 'the airline name is empty');
        require(!airlines[airline].isRegistered, 'the aireline is already registered');

        airlines[airline] = Airline({
            isRegistered: true,
            name: name,
            totalFund: 0
        });
        countOfAirlines ++;

        emit AirlineRegistered(airline, registrant, name);
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address airline,
                                address registrant,
                                string name
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            returns(bool)
    {
        _addAirline(airline, registrant, name);
        return true;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    *      Can only be called from FlightSuretyApp contract
    */   
    function fundAirline
                            (
                                address airline
                            )
                            external
                            payable
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        require(airlines[airline].isRegistered, 'the aireline is not registered');

        airlines[airline].totalFund += msg.value;
    }

// endregion

// region Insurance MANAGEMENT

    /*****************************************************************
     * the following variable are insurance related
     ****************************************************************/

    struct InsuranceInfo {
        bytes32 flightKey;              // flight key
        address airline;                // flight info: airline
        string flight;                  // flight info: flight
        uint256 flightTimestamp;        // flight info: time
        uint256 insuranceFund;          // issurance info: the credit the passenger paied
        uint256 insurancePayback;       // issurance info: the credit the passenger is paid back in case of delay
        uint256 insuranceTimestamp;     // issurance info: time
    }
    mapping(address => InsuranceInfo[]) passengerInsurance;

    event PassengerBuyInsurance(address passenger, address airline, string flight, uint256 timestamp);
    event InsurancePaidbackCredit(address passenger, address airline, string flight, uint256 timestamp);

    event PassengerWithdraw(address passenger);

   /**
    * @dev Buy insurance for a flight
    *      Can only be called from FlightSuretyApp contract
    */   
    function buyInsurance
                            (
                                address passenger,
                                address airline,
                                string flight,
                                uint256 timestamp,
                                uint256 insurancePayback
                            )
                            external
                            payable
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        require(passenger != address(0), 'invalid passenger');
        require(airline != address(0), 'invalid airline');
        require(msg.value > 0, 'please pay to buy insurance');
        require(insurancePayback >= msg.value, 'no pay back to the insuree');
        require(airlines[airline].totalFund >= FUND_FEE_AIRLINE, 'the airline has not funded enough');

        bytes32 flightKey = _getFlightKey(airline, flight, timestamp);

        // validate no duplicated insurance of the same flight
        InsuranceInfo[] storage insurances = passengerInsurance[passenger];
        for (uint index=0; index<insurances.length; index++) {
            require(insurances[index].flightKey != flightKey, 'you already buy insurance of the flight');
        }

        // appended the insurance of the same flight
        passengerInsurance[passenger].push(InsuranceInfo({
            flightKey: flightKey,
            airline: airline,
            flight: flight,
            flightTimestamp: timestamp,
            insuranceFund: msg.value,
            insurancePayback: insurancePayback,
            insuranceTimestamp: now
        }));
        emit PassengerBuyInsurance(passenger, airline, flight, timestamp);
    }

    /**
     *  @dev Credits payouts to insurees
     *      Can only be called from FlightSuretyApp contract
     */
    function creditInsurees
                                (
                                    address passenger,
                                    address airline,
                                    string flight,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    {
        require(passenger != address(0), 'invalid passenger');
        require(airline != address(0), 'invalid airline');
        require(airlines[airline].totalFund >= FUND_FEE_AIRLINE, 'the airline has not funded enough');

        bytes32 flightKey = _getFlightKey(airline, flight, timestamp);

        // let's find the insurance
        bool foundInsurance = false;
        InsuranceInfo[] storage insurances = passengerInsurance[passenger];
        for (uint index=0; index<insurances.length; index++) {
            if (insurances[index].flightKey == flightKey) {
                foundInsurance = true;

                // refund the passenger
                passengerCredits[passenger] += insurances[index].insurancePayback;

                // delete current insurance, coz we already paid back to the passenger.
                //   it also prevents from double pay-back.
                if (insurances.length == 1) {
                    delete passengerInsurance[passenger];
                } else {
                    if (index != insurances.length-1) {
                        passengerInsurance[passenger][index] = passengerInsurance[passenger][insurances.length-1];
                    }
                    passengerInsurance[passenger].length --;
                }

                emit InsurancePaidbackCredit(passenger, airline, flight, timestamp);
                break;
            }
        }
        require(foundInsurance, 'the insurance is not found (or maybe has beed paid back)');
    }
    
    /**
     *  @dev Transfers eligible payout funds to insuree
     *      Can only be called from FlightSuretyApp contract
    */
    function payWithdraw
                            (
                                address passenger,
                                uint256 amount
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        // check
        require(passenger != address(0), 'invalid passenger');
        require(amount > 0, 'please specify the amount to withdraw');
        require(passengerCredits[msg.sender] >= amount, 'User pays more than her/his credit');

        // effect
        if (passengerCredits[msg.sender] == amount) {
            delete passengerCredits[msg.sender];
        } else {
            passengerCredits[msg.sender] -= amount;
        }

        // result
        msg.sender.transfer(amount);
        emit PassengerWithdraw(msg.sender);
    }

// endregion

    /**
     * Utils function to caculate flight key
     */
    function _getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        if ((msg.value > 0) && airlines[msg.sender].isRegistered) {
            airlines[msg.sender].totalFund += msg.value;
        }
    }
}

