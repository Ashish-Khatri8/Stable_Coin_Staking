const { ethers } = require("hardhat");

async function main() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const STAKING_MULTI_V1_PROXY_ADDRESS = "";
    const USDC_Token = "0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b";
    const USDC_Price_Feed = "0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB";

    // Get the upgradable Staking_Multi_V2 contract.
    const Staking_Multi_V2 = await ethers.getContractFactory("Staking_Multi_V2");
    const staking_Multi_V2 = await Staking_Multi_V2.attach(STAKING_MULTI_V1_PROXY_ADDRESS);

    await staking_Multi_V2.addTokenSupport(
        USDC_Token, 
        USDC_Price_Feed
    );
    
    // Check whether support for USDC tokens are supported for staking or not.
    console.log(await staking_Multi_V2.supportedTokens(1));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });
