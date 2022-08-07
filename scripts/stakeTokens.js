const { ethers, upgrades } = require("hardhat");

async function main() {
    const [owner, addr1] = await ethers.getSigners();

    const STAKING_MULTI_V1_PROXY_ADDRESS = "0x35E901deCf363Fd7C5c14cFE5A2DB2EC2DdFb39c";

    // Get the upgradable Staking_Multi_V1 contract.
    const Staking_Multi_V1 = await ethers.getContractFactory("Staking_Multi_V1");
    const staking_Multi_V1 = await Staking_Multi_V1.attach(STAKING_MULTI_V1_PROXY_ADDRESS);

    // Get the DAI contract.
    const DAI = await ethers.getContractFactory("Dai");
    const dai = await DAI.attach("0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa");

    // Give staking contract allowance of Dai tokens.
    await dai.connect(addr1).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 24));

    // Stake the Dai tokens.
    await staking_Multi_V1.connect(addr1).stakeTokens(0, 1000000);
    console.log("Staked 1000000 dai tokenBits.");

}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });
