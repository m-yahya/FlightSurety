
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async () => {

    let result = null;
    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            display('Operational Status', 'Check if contract is operational', [{
                label: 'Operational Status',
                error: error,
                value: result
            }]);
        });
        populateSelect("flights", contract.flights, 1);
        populateSelect("flights", contract.flights, 2);
        flightChange('flights', 1, contract.flights);
        flightChange('flights', 2, contract.flights);

        DOM.elid('flights2').addEventListener('change', () => {
            flightChange('flights', 2, contract.flights);
        });

        DOM.elid('buy').addEventListener('click', () => {
            let flight = DOM.elid('flights2').value;
            let amount = DOM.elid('insurance-amount').value;
            if (amount !== "" || amount === 0) {
                contract.buy(flight, amount, (error, result) => {
                    if (!error) {
                        alert(`Passenger is insured on : ${flight}`);
                        console.log(result);
                    }
                });
            } else {
                alert("Insurance Amount is required and should be a number greater than zero.");
            }
        });

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flights1').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [{ label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp }]);
            });
        })

    });

})();

function populateSelect(type, selectOpts, el) {
    let select = DOM.elid(type + el);
    selectOpts.forEach(opt => {
        if (type === 'airline') {
            select.appendChild(DOM.option({ value: opt.address }, opt.name));
        } else if (type === 'flights') {
            select.appendChild(DOM.option({ value: opt.flightNumber }, opt.flightNumber));
        }
    });
}

function flightChange(el, n, flights) {
    el = el + n;
    let flight = DOM.elid(el).value;
    let flightArray = [];

    for (let i = 0; i < flights.length; i++) {
        if (flights[i].flightNumber === flight) {
            flightArray.push(flights[i]);
            break;
        }
    }
    let num = el.charAt(el.length - 1);
    if (n > 1)
        displayFlightInfo(num, flightArray);
}

function displayFlightInfo(num, flight) {
    let divname = "flightInfo" + num;
    let displayDiv = DOM.elid(divname);
    displayDiv.innerHTML = "";
    let section = DOM.section();

    let line1 = `Airline:  ${flight[0].airline} Departs time: ${flight[0].time}`;
    let line2 = `Departure From: ${flight[0].origin}`;
    let line3 = `Destination: ${flight[0].destination}`;

    section.appendChild(DOM.div({ className: 'col-sm-6 field' }, line1));
    section.appendChild(DOM.div({ className: 'col-sm-6 field' }, line2));
    section.appendChild(DOM.div({ className: 'col-sm-6 field' }, line3));

    displayDiv.append(section);
}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-sm-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    });
    displayDiv.append(section);

}







