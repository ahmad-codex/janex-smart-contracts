var HDWalletProvider = require("@truffle/hdwallet-provider");
const { MNEMONIC, ETHERSCAN, BSCSCAN } = require('./config/config.json');
const DEV_NODE = "http://127.0.0.1:8545";
const MAINNET_NODE = "wss://mainnet.infura.io/ws/v3/d9c7dc35d6a3442ab74338c9632800cb";
const ROPSTEN_NODE = "wss://ropsten.infura.io/ws/v3/d9c7dc35d6a3442ab74338c9632800cb";
const RINKEBY_NODE = "wss://rinkeby.infura.io/ws/v3/d9c7dc35d6a3442ab74338c9632800cb";
const GOERLI_NODE = "wss://goerli.infura.io/ws/v3/d9c7dc35d6a3442ab74338c9632800cb";
const KOVAN_NODE = "wss://kovan.infura.io/ws/v3/d9c7dc35d6a3442ab74338c9632800cb";
const BSCTEST_NODE = "https://data-seed-prebsc-1-s1.binance.org:8545";
const BSCMAIN_NODE = "https://bsc-dataseed1.binance.org";

module.exports =
{
    plugins: [
        "truffle-plugin-verify"
    ],
    api_keys: {
        etherscan: ETHERSCAN,
        bscscan: BSCSCAN
    },
    networks: {
        development: {
            host: "localhost",
            port: 7545,
            network_id: "*", 		// Match any network id,
            gasPrice: 1000000000, 	// 8 Gwei
        },
        localost: {
            provider: () => new HDWalletProvider(MNEMONIC, DEV_NODE),
            network_id: "7777",
            gas: 7700000,
            gasPrice: 20000000000, // 8 Gwei
            skipDryRun: true,
        },
        mainnet: {
            provider: () => new HDWalletProvider(MNEMONIC, MAINNET_NODE),
            network_id: '1',
            gasPrice: 8000000000, // 8 Gwei
        },
        ropsten: {
            provider: () => new HDWalletProvider(MNEMONIC, ROPSTEN_NODE),
            network_id: '3',
            gasPrice: 8000000000, // 8 Gwei
            skipDryRun: true
        },
        rinkeby: {
            provider: () => new HDWalletProvider(MNEMONIC, RINKEBY_NODE),
            network_id: '4',
            gasPrice: 8000000000, // 8 Gwei
        },
        goerli: {
            provider: () => new HDWalletProvider(MNEMONIC, GOERLI_NODE),
            network_id: '5',
            gasPrice: 8000000000, // 8 Gwei
            confirmations: 1,
            skipDryRun: true,
        },
        kovan: {
            provider: () => new HDWalletProvider(MNEMONIC, KOVAN_NODE),
            network_id: '42',
            gasPrice: 8000000000, // 8 Gwei
            confirmations: 1,
            networkCheckTimeout: 1000000,
            timeoutBlocks: 200,
            skipDryRun: true,
        },
        bsc_test: {
            provider: () => new HDWalletProvider(MNEMONIC, BSCTEST_NODE),
            network_id: '97',
            confirmations: 1,
            skipDryRun: true,
        },
        bsc_main: {
            provider: () => new HDWalletProvider(MNEMONIC, BSCMAIN_NODE),
            network_id: '56',
            confirmations: 1,
            skipDryRun: true,
        },
    },
    compilers: {
        solc: {
            version: "0.8.0",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        }
    },
    mocha: {
        enableTimeouts: false
    }
};
