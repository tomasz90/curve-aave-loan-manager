const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv').config();

module.exports = {
    // See <http://truffleframework.com/docs/advanced/configuration>
    // to customize your Truffle configuration!
    networks: {
        development: {
            host: "127.0.0.1", // Localhost (default: none)
            port: 7548, // Standard Ethereum port (default: none)
            network_id: 10001, // Any network (default: none)
            gas: 600000000,
        },
        matic: {
            provider: () => new HDWalletProvider(process.env.MNEMONIC, 
            "https://polygon-rpc.com/"),
            network_id: 137,
            confirmations: 2,
            timeoutBlocks: 200,
            skipDryRun: true,
            gas: 6000000,
            gasPrice: 50000000000,
        }
    },
    compilers: {
        solc: {
            version: "0.8.6"
        }
    }
};
