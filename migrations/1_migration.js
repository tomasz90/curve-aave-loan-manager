var LoanManager = artifacts.require("./LoanManager.sol");

// polygon
const lendingPoolAddressProvider = "0xd05e3E715d945B59290df0ae8eF85c1BdB684744";

const crvPool = "0x445FE580eF8d70FF569aB36e80c647af338db351";
const am3CrvDeposit = "0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c";
const am3CRV = "0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171";

const dai = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
const usdc = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const usdt = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";

module.exports = function (deployer) {
    deployer.deploy(LoanManager, lendingPoolAddressProvider, crvPool, am3CrvDeposit, am3CRV, dai, usdc, usdt);
};