import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.flights = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts(async (error, accts) => {

            this.owner = accts[0];

            let counter = 1;

            // register airline
            for (let i = 1; i < 5; i++) {
                this.airlines.push({ address: accts[i], name: `Airline ${i}`, funds: 0 })
            }
            this.registerAirlines(accts)

            // register flights
            // Flight
            for (let i = 0; i < 5; i++) {
                let time = Math.floor((Date.now() + (3600 * 1 + i)) / 1000);
                this.flights.push({
                    airline: accts[i],
                    airlineName: `Airline ${i}`,
                    flightNumber: `Flight ${i}`,
                    time: time,
                    origin: `Origin ${i}`,
                    destination: `Destination ${i}`,
                });
            }
            this.registerFlights();

            while (this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner }, callback);
    }

    // register airlines
    async registerAirlines(accts) {
        for (let i = 1; i < accts.length; i++) {
            let airlineAddress = accts[i];
            await this.flightSuretyApp.methods.registerAirline(airlineAddress, `Airline ${i}`).call({ from: accts[0] })
        }
    }

    // register flights
    async registerFlights() {
        for (let i = 0; i < this.flights.length; i++) {
            await this.flightSuretyApp.methods
                .registerFlight(this.flights[i].airline, this.flights[i].flightNumber, this.flights[i].time)
                .call({ from: self.owner });
        }
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let airline;
        for (const item of self.flights) {
            if (item.flightNumber === flight) {
                airline = item.airline;
                break;
            }
        }
        let payload = {
            airline: airline,
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    // buy insurance
    async buy(flight, amount, callback) {
        let self = this;
        let amountToSend = self.web3.utils.toWei(amount, "ether").toString();

        let tempFlight;
        for (const item of self.flights) {
            if (item.flightNumber === flight) {
                tempFlight = item;
                break;
            }
        }
        await self.flightSuretyApp.methods
            .buyPassengerInsurance(tempFlight.flightNumber, self.passengers[0])
            .send({ from: self.passengers[0], value: amountToSend, gas: 3000000 }, (error, result) => {
                callback(error, result);
            });
    }

}


