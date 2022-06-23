# Upgradeable Staking

- An upgradeable ERC20 token staking contract following the TransparentUpgradeableProxy pattern.

- Proxy contracts deployed using "@openzeppelin/hardhat-upgrades" plugin in hardhat.

- All contracts are deployed on the rinkeby test network.

| Contract                                        	|   	| Address                                                                                                                           	|
|-------------------------------------------------	|---	|-----------------------------------------------------------------------------------------------------------------------------------	|
| TransparentUpgradeableProxy BlazeToken Contract 	|   	| [0x9c88ab615084f2f703698104eda5ba9ed1e099fb](https://rinkeby.etherscan.io/address/0x9c88ab615084f2f703698104eda5ba9ed1e099fb)     	|
|                                                 	|   	|                                                                                                                                   	|
| TransparentUpgradeableProxy Staking Contract    	|   	| [<br>0x35E901deCf363Fd7C5c14cFE5A2DB2EC2DdFb39c](https://rinkeby.etherscan.io/address/0x35E901deCf363Fd7C5c14cFE5A2DB2EC2DdFb39c) 	|
|                                                 	|   	|                                                                                                                                   	|
| ProxyAdmin                                      	|   	| [0xd47674c50cBe294849CD92084194a22cD1637101](https://rinkeby.etherscan.io/address/0xd47674c50cBe294849CD92084194a22cD1637101)     	|
|                                                 	|   	|                                                                                                                                   	|
| Staking_Multi_V1 (1st implementation contract)  	|   	| [0x027ebbeB53775cE1410a5E20233e084aB733f97a](https://rinkeby.etherscan.io/address/0x027ebbeB53775cE1410a5E20233e084aB733f97a)     	|
|                                                 	|   	|                                                                                                                                   	|
| BlazeToken (Implementation contract)            	|   	| [0xf97Cadc99f7449888e5407c724309950ffD891Ca](https://rinkeby.etherscan.io/address/0xf97Cadc99f7449888e5407c724309950ffD891Ca)     	|
|                                                 	|   	|                                                                                                                                   	|
| PriceAggregator                                 	|   	| [0xF7f40Fc39763a7e8B88FbBb770Cf414a1aAF47ca](https://rinkeby.etherscan.io/address/0xF7f40Fc39763a7e8B88FbBb770Cf414a1aAF47ca)     	|
|                                                 	|   	|                                                                                                                                   	|
| Dai Token                                       	|   	| [0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa](https://rinkeby.etherscan.io/address/0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa)     	|
|                                                 	|   	|                                                                                                                                   	|
| Dai/USD Chainlink price feed                    	|   	| [0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF](https://rinkeby.etherscan.io/address/0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF)     	|
|                                                 	|   	|                                                                                                                                   	|
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

    Less than 1 month          3%
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
