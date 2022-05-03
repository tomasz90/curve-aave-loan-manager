var LoanManager = artifacts.require("./LoanManager.sol");

module.exports = function(deployer) {
    deployer.deploy(LoanManager);
};