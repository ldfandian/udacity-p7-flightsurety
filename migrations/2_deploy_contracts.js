const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {

    let ownerAirlineName = 'Air China';
    deployer.deploy(FlightSuretyData, "0x0000000000000000000000000000000000000000", ownerAirlineName).then(() => {
        return deployer.deploy(FlightSuretyApp, FlightSuretyData.address).then(() => {
            // during deployment, we authorized app contract to data contract
            FlightSuretyData.deployed().then(async function(instance) {
                try {
                    console.log('Authorize FlightSuretyApp(' + FlightSuretyApp.address + ') to FlightSuretyData(' + FlightSuretyData.address + ')');
                    await instance.authorizeContract(FlightSuretyApp.address);
                } catch(e) {
                    console.log(e)
                }
            });

            // save the config file
            let config = {
                localhost: {
                    url: 'http://localhost:8545',
                    dataAddress: FlightSuretyData.address,
                    appAddress: FlightSuretyApp.address
                }
            }
            fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
            fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
        });
    });
}