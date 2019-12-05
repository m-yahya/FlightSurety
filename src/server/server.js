import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';

import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

// list registered oracles
let registeredOracles = [];

// register 10 oracles on initialization
web3.eth.getAccounts(async (error, accounts) => {
  web3.eth.defaultAccount = accounts[0];

  flightSuretyApp.methods.REGISTRATION_FEE().call({ from: accounts[0] }).then(async function (result) {

    let registrationFee = result.toString()

    let oracles = [];
    let indexes = [];

    for (let i = 0; i < 10; i++) {
      let oracleAccount = accounts[i]

      await flightSuretyApp.methods.registerOracle().send({
        from: oracleAccount,
        value: registrationFee,
        gas: 3000000
      }, async (error, result) => {
        await flightSuretyApp.methods.getMyIndexes().call({


          from: oracleAccount
        }, (error, indexesResult) => {
          if (!error) {
            indexes = indexesResult
            oracles.push(oracleAccount)
            oracles.push(indexes)
            registeredOracles.push(oracles)
            oracles = []
          }
        })
      })

    }
  })
})


flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, async function (error, event) {
  if (error) console.log(error)

  let statusCodes = [0, 10, 20, 30, 40, 50]
  // randomize the status codes
  let randomStatusCode = statusCodes[Math.floor(Math.random() * statusCodes.length)]
  let indexes;
  let oracle;
  // loop through registered oracles to match oracle request event
  for (let i = 0; i < registeredOracles.length; i++) {
    indexes = registeredOracles[i][1]


    if (indexes.indexOf(index.toString()) !== -1) {
      oracle = registeredOracles[i][0]
      try {
        await flightSuretyApp.methods.submitOracleResponse(
          event.returnValues.index,
          event.returnValues.airline,
          event.returnValues.flight,
          event.returnValues.timestamp,
          randomStatusCode
        ).send({ from: oracle, gas: 300000 }, (error, result) => {
          if (error) {
            console.log(error);

          } else {
            console.log(result);

          }
        })
      } catch (e) {
        console.log(e);
      }
    }
  }
});

const app = express();
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

export default app;


