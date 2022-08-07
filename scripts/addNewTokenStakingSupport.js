const { ethers } = require("hardhat");

async function main() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const STAKING_MULTI_V1_PROXY_ADDRESS = "0x35E901deCf363Fd7C5c14cFE5A2DB2EC2DdFb39c";
    const USDC_Token = "0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b";
    const USDC_Price_Feed = "0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB";

    // Get the upgradable Staking_Multi_V2 contract.
    const Staking_Multi_V1 = await ethers.getContractFactory("Staking_Multi_V1");
    const staking_Multi_V1 = await Staking_Multi_V1.attach(STAKING_MULTI_V1_PROXY_ADDRESS);

    await staking_Multi_V1.addTokenSupport(
        USDC_Token, 
        USDC_Price_Feed
    );
    
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });
