pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;          // Account used to deploy contract

    FlightSuretyData private flightSuretyData;

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

// region modifier

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "registered airline" account to be the function caller
    */
    modifier requireRegisteredAirline()
    {
        require(flightSuretyData.isRegisteredAirline(msg.sender), "Caller is not registered airline");
        _;
    }

    /**
    * @dev Modifier that requires the "registered and funded airline" account to be the function caller
    */
    modifier requireFundedAirline()
    {
        require(flightSuretyData.isFundedAirline(msg.sender), "Caller airline is not registered or not funded");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view
                            returns(bool) 
    {
        bool dataContractIsOperational = flightSuretyData.isOperational();
        return dataContractIsOperational;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

// endregion

// region AIRLINE MANAGEMENT

    /*****************************************************************
     * the following variales are airline related
     ****************************************************************/
     
    uint8 public constant MP_AIRLINE_COUNT = 4;                 // the 5th airline need to be approved by 50+ existing airline
    uint8 public constant MP_AIRLINE_APPROVE_PERCENT = 50;      // need 50% of the existing airlines to approve

    // 0: unknown, 1: agree, 2: disagree, (others we don't care for now.)
    uint8 public constant MP_AIRLINE_APPROVE_CODE_AGREE = 1;

    uint256 public constant FUND_FEE_AIRLINE = 1 ether;        // Fee to be paid when registering oracle

    // struct to store the multi-party consensus request info
    struct ApproveResponse {
        address stakeholder;                            // the airline who send the approval response
        uint8 code;                                     // the code that the approval airline send out
    }
    struct AirlineRequest {
        bool isOpen;                                    // the request is still valid
        string name;                                    // name of the airline
        uint256 time;                                   // blockhash time of the new airline request
        ApproveResponse[] approvalResult;               // the result of the approvals, use uint8 for future reasonCode extension
    }
    mapping(address => AirlineRequest) private airlineRequests;         // all the registered airlines
    address[] public airlineRequestKeys;                                // all the registered airlines

    event AirlineApproveRequest(address airline, address registrant, string name);  // the event to request other airlines to approve a new airline
    event AirlineApproveResponse(address airline, address approval, uint code);     // the event to tell one airlines has approved a new airline

    event AirlineRegistered(address airline, address registrant, string name);      // the event to tell a new airline has been registered

    /**
     * @dev Add an airline to the registration queue
     *
     */   
    function registerAirline
                            (
                                address airline,
                                string name
                            )
                            external
                            requireIsOperational
                            requireFundedAirline
                            returns(bool success, uint256 votes)
    {
        require(airline != address(0), 'bad airline address');
        require(bytes(name).length > 0, 'airline name is empty');
        require(!flightSuretyData.isRegisteredAirline(airline), 'the airline is already registered');

        uint count = flightSuretyData.countOfAirlines();
        if (count < MP_AIRLINE_COUNT) {
            success = flightSuretyData.registerAirline(airline, name);
            votes = 1;
            
            if (success) {
                emit AirlineRegistered(airline, msg.sender, name);
            }
        } else {
            require(!airlineRequests[airline].isOpen, 'the airline is already in the waiting list');

            // add it into the request list
            airlineRequests[airline].isOpen = true;
            airlineRequests[airline].name = name;
            airlineRequests[airline].time = now;
            airlineRequests[airline].approvalResult.length = 0; // clear existing votes, if any
            airlineRequests[airline].approvalResult.push(ApproveResponse({
                stakeholder: msg.sender,
                code: MP_AIRLINE_APPROVE_CODE_AGREE
            }));
            airlineRequestKeys.push(airline);

            votes = 1;
            success = false;

            // notify the other existing airlines to approve
            emit AirlineApproveRequest(airline, msg.sender, name);
        }

        return (success, votes);
    }

    /**
     * @dev Add an airline to the registration queue
     * 
     * param(code): 0: unknown, 1: agree, 2: disagree, (others we don't care for now.)
     */   
    function approveAirline
                            (
                                address airline,
                                uint8 code
                            )
                            external
                            requireIsOperational
                            requireFundedAirline
                            returns(bool success, uint256 votes)
    {
        require(!flightSuretyData.isRegisteredAirline(airline), 'the aireline is already registered');
        require(airlineRequests[airline].isOpen, 'the airline is not in the waiting list');

        // 1. check status
        uint voteSameCode = 1; // the caller itself counts
        ApproveResponse[] storage responses = airlineRequests[airline].approvalResult;
        for (uint i=0; i<responses.length; i++) {
            // check if the msg.sender has alread voted before
            require(responses[i].stakeholder != msg.sender, "Caller has already approved.");

            // check current response list for its status
            if (responses[i].code == code) {
                voteSameCode ++;
            }
        }

        // 2. add the vote response of the approval airline
        // store the response data, as the approval history
        airlineRequests[airline].approvalResult.push(ApproveResponse({
            stakeholder: msg.sender,
            code: code
        }));
        success = false;
        votes = responses.length + 1;
        emit AirlineApproveResponse(airline, msg.sender, code);

        // 3. check if we already have a consensus
        uint countOfAirlines = flightSuretyData.countOfAirlines();
        uint percent = voteSameCode.mul(100).div(countOfAirlines);
        if (percent >= MP_AIRLINE_APPROVE_PERCENT) {
            // close the vote, as we already have a consensus
            airlineRequests[airline].isOpen = false;

            // if the consensus is "agree", add it to the registered airline list
            if (code == MP_AIRLINE_APPROVE_CODE_AGREE) {
                string storage name = airlineRequests[airline].name;
                success = flightSuretyData.registerAirline(airline, name);
                if (success) {
                    // for multi-party consensus, we use the first element first and fall back to use msg.sender if not present
                    address registrant = airlineRequests[airline].approvalResult[0].stakeholder;
                    emit AirlineRegistered(airline, registrant, name);
                }
            }

            // remove the airline address from the airline key
            bool foundKey = false;
            for (uint index=0; index<airlineRequestKeys.length; index++) {
                if (airlineRequestKeys[index] == airline) {
                    if (index != (airlineRequestKeys.length-1)) {
                        airlineRequestKeys[index] = airlineRequestKeys[airlineRequestKeys.length-1];
                    }
                    airlineRequestKeys.length --;
                    foundKey = true;
                    break;
                }
            }
            require(foundKey, 'runtim error: something wrong with the airline key');
        }

        return (success, votes);
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
                            requireRegisteredAirline
    {
        require(airline != address(0), 'invalid airline');
        require(msg.value >= FUND_FEE_AIRLINE, 'Not paied enough to fund the airline');

        flightSuretyData.fundAirline.value(msg.value)(airline);
    }

    /**
     * @dev Get the infomation of one particular airline
     */   
    function getAirlineInfomationByIndex
                            (
                                uint256 index
                            )
                            external
                            view
                            requireIsOperational
                            returns(address airline, string name, bool isFunded)
    {
        return flightSuretyData.getAirlineInfomationByIndex(index);
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
                            returns(uint256)
    {
        return flightSuretyData.countOfAirlines();
    }

// endregion

// region FLIGHT MANAGEMENT

    /*****************************************************************
     * the following variales are flight related
     ****************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;   // NOTE: only 20 is interesting in this lesson
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    struct Flight {
        bool isOpen;
        address airline;
        string flight;
        uint256 flightTimestamp;        
        uint8 statusCode;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] private flightIdArray;

    /**
     * Utils function to caculate flight key
     */
    function _getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    address airline,
                                    string flight,
                                    uint256 flightTimestamp
                                )
                                external
                                requireIsOperational
                                requireFundedAirline
    {
        require(flightSuretyData.isRegisteredAirline(airline), 'the airline does not exist');
        require(bytes(flight).length > 0, 'no flight info ');

        bytes32 flightId = _getFlightKey(airline, flight, flightTimestamp);
        require(!flights[flightId].isOpen, 'the flight already exists');

        flights[flightId] = Flight({
            isOpen: true,
            airline: airline,
            flight: flight,
            flightTimestamp: flightTimestamp,
            statusCode: STATUS_CODE_UNKNOWN
        });
        flightIdArray.push(flightId);
    }

    /**
     * the total count of the active flight
     */
    function getFlightCount()
                                external
                                view
                                returns(uint256)
    {
        return flightIdArray.length;
    }

    /**
     * retrieve info of the index-th active flight
     */
    function getFlightInfomation(uint256 index)
                                external
                                view
                                returns(
                                    address airline, string airlineName, bool airlineFunded,
                                    string flight, uint256 flightTimestamp, uint8 statusCode)
    {
        require(index < flightIdArray.length, 'no more flight');

        bytes32 flightId = flightIdArray[index];
        require(flights[flightId].isOpen, 'the flight is not open to insure');

        (airlineName, airlineFunded) = flightSuretyData.getAirlineInfomation(airline);
        Flight storage result = flights[flightId];
        return (result.airline, airlineName, airlineFunded, result.flight, result.flightTimestamp, result.statusCode);
    }                                
    
    /**
     * @dev Called after oracle has updated flight status
     *
     */  
    function _processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        bytes32 flightId = _getFlightKey(airline, flight, timestamp);
        require(flights[flightId].isOpen, 'the flight does not exists');

        flights[flightId].statusCode = statusCode;

        // NOTE: we don't proactively refund the insuree, since the count of insuree probably be very large
        //   and we will exhaust our gas limit to handle it
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        requireIsOperational
    {
        bytes32 flightId = _getFlightKey(airline, flight, timestamp);
        require(flights[flightId].isOpen, 'the flight does not exists');

        uint8 index = _getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

// endregion

// region Insurance MANAGEMENT

    uint256 public constant FUND_FEE_FLIGHT_MAX = 1 ether;              // Fee to be paid when registering oracle

    event PassengerBuyInsurance(address passenger, address airline, string flight, uint256 timestamp);
    event InsurancePaidbackCredit(address passenger, address airline, string flight, uint256 timestamp);

    event PassengerWithdraw(address passenger);

    // Generate a request for oracles to fetch flight information
    function buyInsurance
                        (
                            address passenger,
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        payable
                        requireIsOperational
    {
        require(passenger != address(0), 'invalid passenger');
        require((msg.value > 0) && (msg.value <= FUND_FEE_FLIGHT_MAX), 'invalid payment for the flight insurance');

        // validate it is a valid flight
        bytes32 flightId = _getFlightKey(airline, flight, timestamp);
        require(flights[flightId].isOpen, 'the flight does not exists');

        // calculate payback money and finish buying the insurance
        uint256 insurancePayback = msg.value;
        insurancePayback = insurancePayback.mul(3).div(2);
        flightSuretyData.buyInsurance.value(msg.value)(passenger, airline, flight, timestamp, insurancePayback);

        emit PassengerBuyInsurance(passenger, airline, flight, timestamp);
    }

    // Generate a request for oracles to fetch flight information
    function claimInsurancePayback
                        (
                            address passenger,
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        requireIsOperational
    {
        require(passenger != address(0), 'invalid passenger');

        // validate it is a valid flight
        bytes32 flightId = _getFlightKey(airline, flight, timestamp);
        require(flights[flightId].isOpen, 'the flight does not exists');

        // check flight status
        require(flights[flightId].statusCode == STATUS_CODE_LATE_AIRLINE, 'flight is not delayed, no pay back');

        flightSuretyData.creditInsurees(passenger, airline, flight, timestamp);
        emit InsurancePaidbackCredit(passenger, airline, flight, timestamp);
    }

    function passengerWithdraw
                            (
                                uint256 amount
                            )
                            external
                            requireIsOperational
    {
        require(amount > 0, 'please specify the amount to withdraw');

        flightSuretyData.payWithdraw(msg.sender, amount);
        emit PassengerWithdraw(msg.sender);
    }
      

// endregion

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant ORACLE_REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant ORACLE_MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
        mapping(address => bool) oracles;               // Remember the oracles which has responsed
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    /**
    * @dev Modifier that requires the caller is a valid registered oracle
    */
    modifier requireIsOracleRegistered()
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");
        _;
    }

    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
                            requireIsOperational
    {
        // Require registration fee
        require(msg.value >= ORACLE_REGISTRATION_FEE, 'Registration fee is required');

        if (!oracles[msg.sender].isRegistered) {
            uint8[3] memory indexes = _generateIndexes(msg.sender);
            oracles[msg.sender] = Oracle({
                                            isRegistered: true,
                                            indexes: indexes
                                        });
        }
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            requireIsOracleRegistered
                            returns(uint8[3])
    {
        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
                        requireIsOperational
                        requireIsOracleRegistered
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");
        require(!oracleResponses[key].oracles[msg.sender], 'the oracle already responsed before');

        // remember the vote result
        oracleResponses[key].responses[statusCode].push(msg.sender);
        oracleResponses[key].oracles[msg.sender] = true;

        // Information isn't considered verified until at least ORACLE_MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);

        // check the vote result
        if (oracleResponses[key].responses[statusCode].length >= ORACLE_MIN_RESPONSES) {
            // Handle flight status as appropriate
            _processFlightStatus(airline, flight, timestamp, statusCode);

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function _generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = _getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = _getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = _getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function _getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
