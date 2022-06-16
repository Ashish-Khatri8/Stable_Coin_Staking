# Upgradeable Staking

- An upgradeable ERC20 token staking contract following the TransparentUpgradeableProxy pattern.

- Proxy contracts deployed using "@openzeppelin/hardhat-upgrades" plugin in hardhat.

- All contracts are deployed on the rinkeby test network.

```script
    Contract                                Address

    TransparentUpgradeableProxy             [0x52e21C8a89F67C1c4F861719a8eAA54aA1306ca0](https://rinkeby.etherscan.io/address/0x52e21C8a89F67C1c4F861719a8eAA54aA1306ca0)

    ProxyAdmin                              [0x4771153A6930f02C47fB6c7fC87Dcf48E033a079](https://rinkeby.etherscan.io/address/0x4771153A6930f02C47fB6c7fC87Dcf48E033a079)

    Staking_Multi_V1                        [0x71b00ae543365E686113F6e013555Fd95e152439](https://rinkeby.etherscan.io/address/0x71b00ae543365E686113F6e013555Fd95e152439)
    (1st implementation contract)

    BlazeToken                              [0xD077F2c212738aB64A5cE843F7C60328c7428892](https://rinkeby.etherscan.io/address/0xD077F2c212738aB64A5cE843F7C60328c7428892)

    PriceAggregator                         [0xd371E06BF1cc56B95801F04a22a7A95A58d9Ff22](https://rinkeby.etherscan.io/address/0xd371E06BF1cc56B95801F04a22a7A95A58d9Ff22)

    Dai Token                               [0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa](https://rinkeby.etherscan.io/address/0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa)

    Dai/USD Chainlink price feed            [0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF](https://rinkeby.etherscan.io/address/0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF)

```

---

## Contract: BlazeToken.sol

This contract deploys an **ERC20 token**, which will be given as reward when users unstake their tokens.

- Name: "BlazeToken"
- Symbol: "BLZ"
- Decimals: 18

- There is no initial supply, but the contract owner can call the **mint()** function to mint tokens to an address.
It takes the address and the amount of tokens to mint as arguments.

---

## Contract: PriceAggregator.sol`

- This contract uses Chainlink Aggregator Data Feeds to return the current price of a token in USD.

---

## Contract: Staking_Multi_V1.sol

- A staking contract where users can stake the supported ERC20 tokens in order to get BlazeToken(ERC20 token) as reward.

- Users can call the stakeTokens() function to stake their tokens. It takes the tokenAddressIndex(of supportedTokens array which stores the address of the token user wants to stake) and amount of tokens to stake as arguments.

- Users can call the unstakeTokens() function to unstake their staked tokens.
It takes the tokenAddressIndex(of supportedTokens array) and amount of tokens to unstake as arguments.

- Depending upon how much time has elapsed since the tokens were staked, the interest rate for reward tokens is calculated as:

```script
    Time                       Interest Rate (APR)

    Less than 1 month          0%
    Between 1 and 6 months     5%
    Between 6 and 12 months    10%
    After 12 months            15%
```

- Depending upon the USD value of staked tokens, the additional perks for reward tokens are calculated as:

```script
    USD Value                  Perks (In the form of increment in APR)

    Less than $100             0%
    Between $100 and $500      2%
    Between $500 and $1000     5%
    Greater than $1000         10%
```

- Formula to calculate how much tokens to send as reward:

```script
=> ((interestRate + perks) * stakedAmount * stakedTime) / (100 * 365 days)
```

---

## Contract: Staking_Multi_V2.sol

- This contract is the version 2 of staking implementation contract.

- It added the function **addTokenSupport()** which can only be called by the contract admin for adding staking support for another ERC20 token.

- This function takes 2 arguments: the address of the ERC20 contract and the address of chainlink price feed contract of that token.

---
---

### Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case.

```shell
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help
```
