const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");


describe("Staking_Multi_V1", () => {
    let owner, addr1, addr2, addr3, addr4;
    let BlazeToken, blazeToken, PriceAggregator, priceAggregator, Staking_Multi_V1, staking_Multi_V1;
    let Dai, dai, addr1Rewards, addr2Rewards, addr3Rewards, addr4Rewards;
    const DAI_Contract = "0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa";
    const DAI_Price_Feed = "0x2bA49Aaa16E6afD2a993473cfB70Fa8559B523cF";

    beforeEach(async () => {
        [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

        // Deploy the BlazeToken contract.
        BlazeToken = await ethers.getContractFactory("BlazeToken");
        blazeToken = await BlazeToken.deploy();
        await blazeToken.deployed();

        // Deploy the PriceAggregator contract.
        PriceAggregator = await ethers.getContractFactory("PriceAggregator");
        priceAggregator = await PriceAggregator.deploy();
        await priceAggregator.deployed();

        // Deploy the Staking_Multi_V1 contract.
        Staking_Multi_V1 = await ethers.getContractFactory("Staking_Multi_V1");
        staking_Multi_V1 = await upgrades.deployProxy(
            Staking_Multi_V1,
            [
                owner.address,
                blazeToken.address,
                priceAggregator.address,
                [blazeToken.address],
                [DAI_Price_Feed]
            ],
            {initializer: "initialize"}
        );
        await staking_Multi_V1.deployed();

        // Mint the BlazeTokens to the Staking_Multi_V1 contract.
        await blazeToken.mint(staking_Multi_V1.address, ethers.utils.parseUnits("10", 25));
        
        // Mint blaze tokens to other addresses.
        await blazeToken.mint(addr1.address, ethers.utils.parseUnits("10", 4));
        await blazeToken.mint(addr2.address, ethers.utils.parseUnits("10", 20));
        await blazeToken.mint(addr3.address, ethers.utils.parseUnits("10", 20));
        await blazeToken.mint(addr4.address, ethers.utils.parseUnits("10", 20));

        // Give Staking_Multi_V1 contract allowance for blaze tokens.
        blazeToken.connect(addr1).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 20));
        blazeToken.connect(addr2).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 20));
        blazeToken.connect(addr3).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 20));
        blazeToken.connect(addr4).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 20));
    });

    it("Users can stake tokens.", async () => {
        const stakedTokensBefore = await staking_Multi_V1.totalTokensStaked(addr1.address, 0);
        expect(stakedTokensBefore).to.be.equal(0);

        await staking_Multi_V1.connect(addr1).stakeTokens(0, 1000);
        const stakedTokensAfter = await staking_Multi_V1.totalTokensStaked(addr1.address, 0);
        expect(stakedTokensAfter).to.be.equal(1000);
    });

    it("Users get reward tokens on unstaking.", async () => {
        await staking_Multi_V1.connect(addr1).stakeTokens(0, 1000);

        const blazeTokensBalanceBeforeUnstaking = await blazeToken.balanceOf(addr1.address);
        // Increase evm time by 2 months.
        await ethers.provider.send("evm_increaseTime", [2629743 * 2]);

        // Unstake the tokens.
        await staking_Multi_V1.connect(addr1).unstakeTokens(0, 1000);

        const blazeTokensBalanceAfterUnstaking = await blazeToken.balanceOf(addr1.address);

        expect(blazeTokensBalanceAfterUnstaking).to.not.be.equal(+blazeTokensBalanceBeforeUnstaking + 1000);
    });

});
