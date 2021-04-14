var HDWalletProvider = require("truffle-hdwallet-provider");
require('dotenv').config();

module.exports = {
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
  etherscan: 'AZIRCZGSJY4BTC9EK2C6EEFGYSNKUI315K'
},
    compilers: {
	solc: {
	    version: "0.6.7"
	}
    },
    networks: {
  development: {
	   host: "local-node",
	   port: 8545,
	   network_id: "*", // match any network
	   from: process.env.ADDRESS_1

        },
	rinkeby: {
    provider: function () {
        return new HDWalletProvider(process.env.MNEMONIC, "https://rinkeby.infura.io/v3/" + process.env.INFURA_API_KEY);
    },
	    network_id: 4,
	    skipDryRun: true // To prevent async issues occured on node v. 14. see:
	    // https://github.com/trufflesuite/truffle/issues/3008
	},
  bsc_testnet: {
    provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://data-seed-prebsc-2-s1.binance.org:8545/`),
    network_id: 97,
    confirmations: 10,
    timeoutBlocks: 200,
    skipDryRun: true
  },
  // Moonbase Alpha TestNet
  moonbase: {
  provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://rpc.testnet.moonbeam.network`),
  network_id: 1287
},
  ganache: {
  host: "localhost",
  port: 9545,
  network_id: "*"
}
}
};
