
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[1];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, 'New Airline', { from: config.firstAirline });
        }
        catch (e) {

        }
        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    // custom tests

    // test new airline registration upto 4 registrations
    it('Only existing airline may register a new airline until there are at least four airlines registered', async () => {

        // ARRANGE
        let airline1 = accounts[1]
        let airline2 = accounts[2]
        let airline3 = accounts[3]

        let funds = 10000000000000000000;

        // ACT
        await config.flightSuretyApp.fundAirline(config.firstAirline, { from: config.firstAirline, value: funds });
        await config.flightSuretyApp.registerAirline(airline1, 'Airline 1', { from: config.firstAirline });
        await config.flightSuretyApp.fundAirline(airline1, { from: airline1, value: funds });
        await config.flightSuretyApp.registerAirline(airline2, 'Airline 2', { from: airline1 });
        await config.flightSuretyApp.fundAirline(airline2, { from: airline2, value: funds });
        await config.flightSuretyApp.registerAirline(airline3, 'Airline 3', { from: airline2 });

        let registeredAirline0 = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline);
        let registeredAirline1 = await config.flightSuretyData.isAirlineRegistered.call(airline1);
        let registeredAirline2 = await config.flightSuretyData.isAirlineRegistered.call(airline2);
        let registeredAirline3 = await config.flightSuretyData.isAirlineRegistered.call(airline3);

        // ASSERT
        assert.equal(registeredAirline0, true, "airline0 registration failed");
        assert.equal(registeredAirline1, true, "airline1 registration failed");
        assert.equal(registeredAirline2, true, "airline2 registration failed");
        assert.equal(registeredAirline3, true, "airline3 registration failed");

    })

    // test 50% consensus for registration of 5th airline
    it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {

        // ARRANGE
        let airline1 = accounts[1];
        let airline2 = accounts[2];
        let airline3 = accounts[3];
        let airline4 = accounts[4];
        let airline5 = accounts[5];

        let funds = 10000000000000000000;

        // ACT
        await config.flightSuretyApp.registerAirline(airline4, 'Airline 4', { from: airline1 });
        await config.flightSuretyApp.registerAirline(airline4, 'Airline 4', { from: airline2 });

        await config.flightSuretyApp.fundAirline(airline3, { from: airline3, value: funds });
        await config.flightSuretyApp.registerAirline(airline5, 'Airline 5', { from: airline3 });
        

        let registeredAirline2 = await config.flightSuretyData.isAirlineRegistered.call(airline1);
        let registeredAirline3 = await config.flightSuretyData.isAirlineRegistered.call(airline2);
        let registeredAirline4 = await config.flightSuretyData.isAirlineRegistered.call(airline4);
        let registeredAirline5 = await config.flightSuretyData.isAirlineRegistered.call(airline5);

        // ASSERT
        assert.equal(registeredAirline2, true, "airline2 registration failed");
        assert.equal(registeredAirline3, true, "airline3 registration failed");
        assert.equal(registeredAirline4, true, "airline4 registration failed");
        assert.equal(registeredAirline5, false, "airline5 registration failed");

    });


});
