pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 public constant AIRLINE_REGISTRATION_FEE = 10 ether;
    uint256 private contractBalance = 0 ether;

    address[] public multiCalls = new address[](0);

    // Airline structure
    struct Airline {
        string name;
        uint256 funds;
        bool isRegistered;
    }
    // Passenger structure
    struct Passenger {
        bool isInsured;
        bool[] isPaid;
        uint256[] insurancePaid;
        string[] flights;
    }

    // Keep record of registered airlines
    address[] public registeredAirlines;

    // mapping airlines
    mapping(address => Airline) public airlines;
    // mapping passengers
    mapping(address => Passenger) public passengers;
    // mapping passengers insured for a flight
    mapping(string => address[]) private flightPassengers;
    // mapping passenger insurance payouts
    mapping(address => uint256) private insurancePayouts;
    // keep record of total flight insurance
    mapping(string => uint256) private flightTotalInsurance;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    // event fired when a new airline is registered
    event NewAirline(address airlineAddress, string name, uint256 funds, bool status);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    (
    )
    public
    {
        contractOwner = msg.sender;
        // register first airline for contract owner
        airlines[msg.sender] = Airline('First Airline', 0, true);
        // add airline to airlines list
        registeredAirlines.push(msg.sender);
        // emit airline registration event
        emit NewAirline(msg.sender, 'First Airline', 0, true);
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
    returns (bool)
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

    // Multiparty Consensus utility functions
    function multiCallsLength() external view returns (uint){
        return multiCalls.length;
    }

    function getMultiCallsItem(uint index) external view returns (address){
        return multiCalls[index];
    }

    function addMultiCallsItem(address voter) external {
        multiCalls.push(voter);
    }

    function clearMultiCalls() external {
        multiCalls = new address[](0);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    // Airline resources

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline
    (
        address airlineAddress, string name
    )
    external
    requireIsOperational
    {
        airlines[airlineAddress] = Airline(name, 0, true);
        registeredAirlines.push(airlineAddress);
        emit NewAirline(airlineAddress, name, 0, true);
    }
    // get airline
    function getAirline(address airlineAddress) public view returns (string memory name, uint256 funds, bool isRegistered){
        name = airlines[airlineAddress].name;
        funds = airlines[airlineAddress].funds;
        isRegistered = airlines[airlineAddress].isRegistered;
        return (name, funds, isRegistered);
    }
    // check if airline registration
    function isAirlineRegistered(address airline) external view requireIsOperational returns (bool status){
        return airlines[airline].isRegistered;
    }
    // get total number of airlines
    function getToalAirlines() external view requireIsOperational returns (uint256 number){
        return registeredAirlines.length;
    }
    // check if airline is funded
    function isAirlineFunded(address airline) public view requireIsOperational returns (bool status){
        return airlines[airline].funds >= AIRLINE_REGISTRATION_FEE;
    }
    // get airline funds
    function getAirlineFunds(address airline) external view requireIsOperational returns (uint256 fund){
        return airlines[airline].funds;
    }

    // contract resources
    // get contract balance
    function getContractBalance() external view requireIsOperational returns (uint256 balance){
        return contractBalance;
    }

    // flight resources

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy
    (
        string memory flight, address passenger, uint256 amount
    )
    public requireIsOperational
    {
        string[] memory flights = new string[](5);
        bool[] memory paid = new bool[](5);
        uint256[] memory insurance = new uint256[](5);
        uint index;

        // check if passenger is insured
        if (passengers[passenger].isInsured) {
            index = getFlightIndex(passenger, flight);
            // check if passenger already has insurance for the flight
            require(index == 0, 'Flight is already insured');

            passengers[passenger].isPaid.push(false);
            passengers[passenger].insurancePaid.push(amount);
            passengers[passenger].flights.push(flight);
        } else {
            // buy insurance
            paid[0] = false;
            insurance[0] = amount;
            flights[0] = flight;

            passengers[passenger] = Passenger({
                isInsured : true,
                isPaid : paid,
                insurancePaid : insurance,
                flights : flights
                });
        }

        // add insurance to contractBalance
        contractBalance = contractBalance.add(amount);
        // add passengers to flight
        flightPassengers[flight].push(passenger);
        // add to total flight insurance
        flightTotalInsurance[flight] = flightTotalInsurance[flight].add(amount);
    }

    // get passengers insured for a flight
    function getPassengersInsured(string flight) external view requireIsOperational returns (address[] passengersInsured){
        return flightPassengers[flight];
    }
    // get passenger credits
    function getPassengerCredits(address passenger) external view requireIsOperational returns (uint256 credit) {
        return insurancePayouts[passenger];
    }
    // get insurence amount
    function getInsuranceAmount(string flight, address passenger) external view requireIsOperational returns (uint amount){
        amount = 0;
        uint index = getFlightIndex(passenger, flight) - 1;
        // check if passenger is paid
        if (passengers[passenger].isPaid[index] == false) {
            amount = passengers[passenger].insurancePaid[index];
        }
        return amount;
    }
    // set insurance amount
    function setInsurance(string flight, address passenger, uint amount) external requireIsOperational {
        uint index = getFlightIndex(passenger, flight) - 1;
        passengers[passenger].isPaid[index] = true;
        insurancePayouts[passenger] = insurancePayouts[passenger].add(amount);
    }
    // withdraw insurance
    function withdraw(address payee) external payable requireIsOperational {
        require(insurancePayouts[payee] > 0, 'Payout is required');
        uint amount = insurancePayouts[payee];
        insurancePayouts[payee] = 0;
        contractBalance = contractBalance.sub(amount);
        payee.transfer(amount);
    }

    // get flight index
    function getFlightIndex(address passenger, string memory flight) public view returns (uint index){
        string[] memory flights = new string[](5);
        flights = passengers[passenger].flights;
        for (uint i = 0; i < flights.length; i++) {
            if (uint(keccak256(abi.encodePacked(flights[index]))) == uint(keccak256(abi.encodePacked(flight)))) {
                return (i + 1);
            }
        }
        return (0);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund
    (
        uint256 fundAmount, address sender
    )
    public
    payable
    requireIsOperational
    {
        airlines[sender].funds = airlines[sender].funds.add(fundAmount);
        contractBalance = contractBalance.add(fundAmount);
    }

    function getFlightKey
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    external
    view
    requireIsOperational
    returns (bytes32)
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
        contractBalance = contractBalance.add(msg.value);
    }


}

