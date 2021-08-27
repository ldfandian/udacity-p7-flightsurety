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
                                    address airline,
                                    string airlineName
                                ) 
                                public 
    {
        require(bytes(airlineName).length > 0, 'bad airline name');
        contractOwner = msg.sender;
        if (airline == address(0)) {
            _addAirline(msg.sender, airlineName);
        } else {
            _addAirline(airline, airlineName);      // use msg.sender if airline address is not empty
        }

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

    uint256 public constant FUND_FEE_AIRLINE = 1 ether;        // Fee to be paid when registering oracle

    struct Airline {
        bool isRegistered;
        string name;                                                    // name of the airline
        uint256 totalFund;                                              // total balance (in wei) that the airline has funded
    }

    mapping(address => Airline) private airlines;                       // all the registered airlines (excluding wait-for-approval airlines)
    address[] private airlineAddresses;

    /**
     * @dev Check if an airline is registered
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

    /**
     * @dev Check if an airline is registered and funded
     *
     */   
    function isFundedAirline
                            (
                                address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return (airlines[airline].isRegistered && (airlines[airline].totalFund >= FUND_FEE_AIRLINE));
    }

    function _addAirline
                            (   
                                address airline,
                                string name
                            )
                            internal
    {
        require(airline != address(0), 'empty airline address');
        require(bytes(name).length > 0, 'the airline name is empty');
        require(!airlines[airline].isRegistered, 'the airline is already registered');

        airlines[airline] = Airline({
            isRegistered: true,
            name: name,
            totalFund: 0
        });
        airlineAddresses.push(airline);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */   
    function registerAirline
                            (   
                                address airline,
                                string name
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            returns(bool)
    {
        _addAirline(airline, name);
        return true;
    }

    /**
     * @dev Get the Information of one particular airline
     *      Can only be called from FlightSuretyApp contract
     *
     */   
    function getAirlineInfoByIndex
                            (
                                uint32 index
                            )
                            external
                            view
                            requireIsOperational
                            returns(address airline, string name, bool isFunded)
    {
        require(airlineAddresses.length > index, 'the index is invalid');

        airline = airlineAddresses[index];
        require(airlines[airline].isRegistered, 'the airline is not registered');

        return (
            airline,
            airlines[airline].name,
            (airlines[airline].totalFund >= FUND_FEE_AIRLINE)
        );
    }

    /**
     * @dev Retrieve the count of all airline
     */   
    function countOfAirlines
                            (
                            )
                            external
                            view
                            requireIsOperational
                            returns(uint32)
    {
        return (uint32)(airlineAddresses.length);
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
        require(airlines[airline].isRegistered, 'the airline is not registered');

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
        bool success = false;
        InsuranceInfo[] storage insurances = passengerInsurance[passenger];
        for (uint index=0; index<insurances.length; index++) {
            if (insurances[index].flightKey == flightKey) {
                success = true;

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

                break;
            }
        }
        require(success, 'the insurance is not found (or maybe has beed paid back)');
    }
    
    /**
     * get the passender's current balance
     *      Can only be called from FlightSuretyApp contract
     */
    function getPassengerInsurances
                            (
                                address passenger
                            )
                            external
                            view
                            requireIsOperational
                            requireIsCallerAuthorized
                            returns (uint8 count, uint256 balance)
    {
        // check
        require(passenger != address(0), 'invalid passenger');

        count = (uint8)(passengerInsurance[passenger].length);
        balance = passengerCredits[passenger];
    }
    
    /**
     * get the passender's insurance info
     *      Can only be called from FlightSuretyApp contract
     */
    function getPassengerInsuranceByIndex
                            (
                                address passenger,
                                uint8 index
                            )
                            external
                            view
                            requireIsOperational
                            requireIsCallerAuthorized
                            returns (address airline, string flight, uint256 flightTimestamp,
                                uint256 insuranceFund, uint256 insurancePayback)
    {
        require(passenger != address(0), 'invalid passenger');

        InsuranceInfo[] storage infos = passengerInsurance[passenger];
        require(infos.length > index, 'invalid index');
        InsuranceInfo storage info = infos[index];
        return (
            info.airline, info.flight, info.flightTimestamp,
            info.insuranceFund, info.insurancePayback
        );
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
        require(passengerCredits[passenger] >= amount, 'User pays more than her/his credit');

        // effect
        if (passengerCredits[passenger] == amount) {
            delete passengerCredits[passenger];
        } else {
            passengerCredits[passenger] -= amount;
        }

        // result
        passenger.transfer(amount);
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

