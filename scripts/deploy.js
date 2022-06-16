const { ethers } = require("hardhat");

async function main() {
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const Dai_Token_Contract = "0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa";
    const Dai_Price_Feed = "0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF";

    // Deploy the BlazeToken contract.
    const BlazeToken = await ethers.getContractFactory("BlazeToken");
    const blazeToken = await BlazeToken.deploy();
    await blazeToken.deployed();
    console.log("BlazeToken contract deployed at: ", blazeToken.address);

    // Deploy the PriceAggregator contract.
    const PriceAggregator = await ethers.getContractFactory("PriceAggregator");
    const priceAggregator = await PriceAggregator.deploy();
    await priceAggregator.deployed();
    console.log("PriceAggregator contract deployed at: ", priceAggregator.address);

    // Deploy the Staking_Multi_V1 upgradeable contract.
    const Staking_Multi_V1 = await ethers.getContractFactory("Staking_Multi_V1");
    const staking_Multi_V1 = await upgrades.deployProxy(
        Staking_Multi_V1,
        [
            owner.address,
            blazeToken.address,
            priceAggregator.address,
            [Dai_Token_Contract],
            [Dai_Price_Feed]
        ],
        {initializer: "initialize"}
    );

    await staking_Multi_V1.deployed();
    console.log("Staking_Multi_V1 Proxy deployed at: ", staking_Multi_V1.address);

    // Mint BlazeTokens to the Staking contract.
    await blazeToken.mint(staking_Multi_V1.address, ethers.utils.parseUnits("10", 7));
    console.log("Minted 100 million blaze tokens to the staking contract.");

}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });
