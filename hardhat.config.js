require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {version: "0.8.4"},
      {version: "0.5.12"},
      {version: "0.4.17"},
      {version: "0.4.24"},
    ]
  },
  networks: {
    rinkeby: {
      url: process.env.RINKEBY_HTTP_INFURA || '',
      accounts: {
        mnemonic: process.env.MNEMONICS,
      },
      chainId: 4,
      gas: 12000000
    },
    ropsten: {
      url: process.env.ROPSTEN_HTTP_INFURA || '',
      accounts: {
        mnemonic: process.env.MNEMONICS,
      },
      chainId: 3,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  }
};
