pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 private contractBalance = 0 ether;

    // Airline structure
    struct Airline{
        string name;
        uint256 funds;
        bool isRegistered;
    }

    // Keep record of registered airlines
    address[] public registeredAirlines;

    // mapping airlines
    mapping (address => Airline) public airlines;

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
                            address airlineAddress, string calldata name
                            )
                            external
                            requireIsOperational
    {
        airlines[airlineAddress] = Airline(name, 0, true);
        registeredAirlines.push(airlineAddress);
        emit NewAirline (airlineAddress, name, 0, true);
    }
    // get airline
    function getAirline (address airlineAddress) public view returns(string memory name, uint256 funds, bool isRegistered){
        name = airlines[airlineAddress].name;
        funds = airlines[airlineAddress].funds;
        isRegistered = airlines[airlineAddress].isRegistered;
        return (name, funds, isRegistered);
    }
    // check if airline registration
    function isAirlineRegistered(address airline) external view requireIsOperational returns(bool status){
        return airlines[airline].isRegistered;
    }
    // get total number of airlines
    function getToalAirlines()external view requireIsOperational returns(uint256 number){
        return registeredAirlines.length;
    }
    // check if airline is funded
    function isAirlineFunded(address airline) public view requireIsOperational returns(bool status){
        return airlines[airline].funds >= AIRLINE_REGISTRATION_FEE;
    }

    // contract resources
    // get contract balance
    function getContractBalance() external view requireIsOperational returns (uint256 balance){
        return contractBalance;
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
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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
    {
    }

    function getFlightKey
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

