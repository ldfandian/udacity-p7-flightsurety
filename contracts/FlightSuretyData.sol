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

    /**
     * the following variable are airline related
     */
    struct Airline {
        bool isRegistered;
        string name;                                                    // name of the airline
        uint256 totalFund;                                              // total balance (in wei) that the airline has funded
    }
    uint256 public constant FUND_FEE_AIRLINE = 10 ether;                // Fee to be paid when registering oracle

    uint public countOfAirlines = 0;                                    // count of the registered airlines
    mapping(address => Airline) private airlines;                       // all the registered airlines (excluding wait-for-approval airlines)

    event AirlineRegistered(address airline, address registrant, string name);              // the event to request other airlines to approve a new airline


    /**
     * the following variable are user related
     */
    mapping(address => uint256) private userBalances;

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
                            requireIsCallerAuthorized
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
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
                            requireIsOperational
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                uint256 amount
                            )
                            external
                            payable
                            requireIsOperational
    {
        // check
        require(userBalances[msg.sender] >= amount, 'User pays more than her/his credit');

        // effect
        if (userBalances[msg.sender] == amount) {
            delete userBalances[msg.sender];
        } else {
            userBalances[msg.sender] -= amount;
        }

        // result
        msg.sender.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
    {
        require(airlines[msg.sender].isRegistered, 'Caller is not a registered airline');
        require(msg.value >= FUND_FEE_AIRLINE, 'Not paied enough to fund the airline');

        airlines[msg.sender].totalFund += msg.value;
    }

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
        fund();
    }


}

