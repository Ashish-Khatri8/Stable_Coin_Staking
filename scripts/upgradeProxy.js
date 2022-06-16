const { ethers, upgrades } = require("hardhat");

async function main() {
    const [owner, addr1] = await ethers.getSigners();

    const STAKING_MULTI_V1_PROXY_ADDRESS = "";

    // Get the upgradable Staking_Multi_V2 contract.
    const Staking_Multi_V2 = await ethers.getContractFactory("Staking_Multi_V2");
 
    // Upgrade the contract.
    const staking_Multi_V2 = await upgrades.upgradeProxy(
        STAKING_MULTI_V1_PROXY_ADDRESS,
        Staking_Multi_V2,
    );
    await staking_Multi_V2.deployed();
    console.log("Staking_Multi_V2 deployed at: ", staking_Multi_V2.address);
    
    // Check whether previously staked tokens are still present or not.
    console.log(await staking_Multi_V2.totalTokensStaked(addr1.address, 0));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });
