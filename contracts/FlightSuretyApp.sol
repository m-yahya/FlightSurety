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
    FlightSuretyData flightSuretyData;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    // consensus for new airline registration
    uint8 private constant AIRLINE_REGISTRATION_CONSENSUS = 4;
    // maximum insurance amount
    uint256 public constant MAX_INSURANCE = 1 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string flight;
    }

    mapping(bytes32 => Flight) private flights;

    // events
    // event fired when a flight is registered
    event RegisterFlight(string flight, uint256 time);


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
        // Modify to call data contract's status
        require(true, "Contract is currently not operational");
        _;
        // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
    (
        address dataContractAddr
    )
    public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContractAddr);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
    public
    view
    returns (bool)
    {
        return flightSuretyData.isOperational();
        // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline
    (
        address airline, string name
    )
    external
    requireIsOperational
    returns (bool success, uint256 votes)
    {
        // check if airline is registered
        bool isRegistered = flightSuretyData.isAirlineRegistered(msg.sender);
        require(isRegistered, 'Caller is not a registered airline');

        // check is airline is already registered
        isRegistered = flightSuretyData.isAirlineRegistered(airline);
        require(!isRegistered, "Airline is already a registered airline");

        // check if airline has funds
        bool isFunded = flightSuretyData.isAirlineFunded(msg.sender);
        require(isFunded, 'Airline is not funded');
        //  get total number of registered airlines
        uint totalAirlines = flightSuretyData.getToalAirlines();
        // apply consensus
        if (totalAirlines >= AIRLINE_REGISTRATION_CONSENSUS) {
            bool isDuplicate = false;
            for (uint index = 0; index < flightSuretyData.multiCallsLength(); index++) {
                if (flightSuretyData.getMultiCallsItem(index) == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, 'Caller can only vote once');
            flightSuretyData.addMultiCallsItem(msg.sender);

            // apply 50% consensus
            if (flightSuretyData.multiCallsLength() >= totalAirlines.div(2)) {
                flightSuretyData.clearMultiCalls();
                flightSuretyData.registerAirline(airline, name);
            }

        } else {
            flightSuretyData.registerAirline(airline, name);
        }
        return (success, 0);
    }

    // fund airline
    function fundAirline(address airline) external payable requireIsOperational {
        flightSuretyData.fund(msg.value, airline);
    }

    function getAirlineFunds(address airline) external view returns (uint256 funds) {
        return flightSuretyData.getAirlineFunds(airline);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight
    (
        address airline, string flight, uint256 time
    )
    external
    requireIsOperational
    {
        bytes32 key = getFlightKey(airline, flight, time);
        require(!flights[key].isRegistered, 'Flight is already registered');
        flights[key] = Flight({
            isRegistered : true,
            statusCode : STATUS_CODE_UNKNOWN,
            airline : airline,
            flight : flight,
            updatedTimestamp : time
            });
        emit RegisterFlight(flight, block.timestamp);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus
    (
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
    internal
    requireIsOperational
    {
        bytes32 flightKey = flightSuretyData.getFlightKey(airline, flight, timestamp);
        flights[flightKey].statusCode = statusCode;
        require(statusCode == STATUS_CODE_LATE_AIRLINE, 'Only late airlines can be processed');
        address[] memory passengers = flightSuretyData.getPassengersInsured(flight);
        uint amount = 0;
        address passenger;

        for (uint i = 0; i < passengers.length; i++) {
            passenger = passengers[i];
            amount = flightSuretyData.getInsuranceAmount(flight, passenger);
            amount = amount.mul(15).div(10);
            flightSuretyData.setInsurance(flight, passenger, amount);
        }
    }

    // buy insurance
    function buyPassengerInsurance(string flight, address passenger) external payable requireIsOperational {
        require(msg.value <= MAX_INSURANCE, 'Passenger need to pay upto 1 ether');
        flightSuretyData.buy(flight, passenger, msg.value);
    }
    // get passenger credits
    function getPassengerCredits(address passenger) external view requireIsOperational returns (uint256 credit) {
        return flightSuretyData.getPassengerCredits(passenger);
    }
    // withdraw payouts
    function withdrawPayout() external {
        flightSuretyData.withdraw(msg.sender);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester : msg.sender,
            isOpen : true
            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


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


    // Register an oracle with the contract
    function registerOracle
    (
    )
    external
    payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            isRegistered : true,
            indexes : indexes
            });
    }

    function getMyIndexes
    (
    )
    view
    external
    returns (uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

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
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    pure
    internal
    returns (bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
    (
        address account
    )
    internal
    returns (uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
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
            nonce = 0;
            // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion

}   
