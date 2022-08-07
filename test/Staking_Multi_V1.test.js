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
        blazeToken = await upgrades.deployProxy(
            BlazeToken,
            [],
            {initializer: "initialize"}
        );
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
                blazeToken.address,
                priceAggregator.address,
                [DAI_Contract],
                [DAI_Price_Feed]
            ],
            {initializer: "initialize"}
        );
        await staking_Multi_V1.deployed();
        
        // Get the DAI contract.
        Dai = await ethers.getContractFactory("Dai");
        dai = await Dai.attach(DAI_Contract);

        // Mint the BlazeTokens to the Staking_Multi_V1 contract.
        await blazeToken.mint(staking_Multi_V1.address, ethers.utils.parseUnits("10", 28));
    
        // Give Staking_Multi_V1 contract allowance for Dai tokens.
        dai.connect(addr1).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 22));
        dai.connect(addr2).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 22));
        dai.connect(addr3).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 22));
        dai.connect(addr4).approve(staking_Multi_V1.address, ethers.utils.parseUnits("10", 22));

    });

    it("Only owner can add staking support for new token.", async () => {
        await expect(staking_Multi_V1.connect(addr1).addTokenSupport(
            DAI_Contract, DAI_Price_Feed
        )).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Owner cannot add duplicate token support.", async() => {
        await expect(staking_Multi_V1.connect(owner).addTokenSupport(
            DAI_Contract, DAI_Price_Feed
        )).to.be.revertedWith("Staking_Multi_V1: Token already supported for staking!");
    });

    it("Users cannot stake an unsupported token.", async () => {
        await blazeToken.mint(addr1.address, 1000);
        await blazeToken.connect(addr1).approve(staking_Multi_V1.address, 1000);
        await expect(staking_Multi_V1.stakeTokens(1, 1000))
            .to.be.revertedWith("Staking_Multi_V1: Token not supported for staking.");
    });

    it("Users can stake supported tokens.", async () => {
        const userStakeBefore = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeBefore.stakedAmount).to.be.equal(0);

        await staking_Multi_V1.connect(addr1).stakeTokens(0, 100000);
        const userStakeAfter = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeAfter.stakedAmount).to.be.equal(100000);
    });

    it("Users can stake supported tokens multiple times and Reward updates.", async () => {
        const userStakeBefore = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeBefore.stakedAmount).to.be.equal(0);

        await staking_Multi_V1.connect(addr1).stakeTokens(0, 100000);
        const userStakeAfter = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeAfter.stakedAmount).to.be.equal(100000);

        // Increase evm time by 2 months.
        await ethers.provider.send("evm_increaseTime", [2629743 * 2]);

        // Stake again
        await staking_Multi_V1.connect(addr1).stakeTokens(0, 100000);
        const userStakeAfterAgain = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeAfterAgain.stakedAmount).to.be.equal(200000);

        // Check reward.
        expect(await userStakeAfterAgain.rewardAmount).to.not.be.equal(0);
    });

    it("User gets reward tokens on unstaking.", async () => {
        const userStakeBefore = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeBefore.stakedAmount).to.be.equal(0);

        await staking_Multi_V1.connect(addr1).stakeTokens(0, 10000000);
        const userStakeAfter = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeAfter.stakedAmount).to.be.equal(10000000);

        // Increase evm time by 7 months.
        await ethers.provider.send("evm_increaseTime", [2629743 * 7]);

        // Check balance of user's reward tokens before unstaking.
        const userRewardTokenBalanceBefore = await blazeToken.balanceOf(addr1.address);

        // Unstake the tokens.
        await staking_Multi_V1.connect(addr1).unstakeTokens(0, 10000000);

        // Check whether all values of user's stake got set to 0 as all tokens unstaked.
        const userStakeAfterUnstaking = await staking_Multi_V1.userStakes(addr1.address, 0);
        expect(await userStakeAfterUnstaking.stakedAmount).to.be.equal(0);
        expect(await userStakeAfterUnstaking.rewardAmount).to.be.equal(0);
        expect(await userStakeAfterUnstaking.lastTimeRewardsUpdated).to.be.equal(0);

        // Check reward balance of user after unstaking.
        const userRewardTokenBalanceAfter = await blazeToken.balanceOf(addr1.address);
        expect(userRewardTokenBalanceAfter).to.not.be.equal(userRewardTokenBalanceBefore);

    });

    it("Owner can upgrade implementation contract and previous user stakes are not changed.", async () => {
        // Stake dai tokens before upgrading implementation contract.
        await staking_Multi_V1.connect(addr3).stakeTokens(0, 10000000);
        const userStakeBeforeUpgrading = await staking_Multi_V1.userStakes(addr3.address, 0);
        expect(await userStakeBeforeUpgrading.stakedAmount).to.be.equal(10000000);
        
        // Upgrade the implementation contract.
        const staking_Multi_V2 = await upgrades.upgradeProxy(
            staking_Multi_V1.address,
            Staking_Multi_V1
        );
        await staking_Multi_V2.deployed();

        // Now check whether after upgradation, previous stakes are there or not.
        const userStakeAfterUpgrading = await staking_Multi_V1.userStakes(addr3.address, 0);
        expect(await userStakeAfterUpgrading.stakedAmount)
            .to.be.equal(await userStakeBeforeUpgrading.stakedAmount);
    });

});
