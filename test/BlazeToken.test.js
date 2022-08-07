const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BlazeToken", () => {

    const tokenName = "BlazeToken";
    const tokenSymbol = "BLZ";

    let owner, address1;
    let BlazeToken, blazeToken;

    beforeEach(async () => {
        [owner, address1] = await ethers.getSigners();
        BlazeToken = await ethers.getContractFactory("BlazeToken");
        blazeToken = await upgrades.deployProxy(
            BlazeToken,
            [],
            {initializer: "initialize"}
        );
        await blazeToken.deployed();
    });

    it("Sets correct token name and symbol", async () => {
        expect(await blazeToken.name()).to.equal(tokenName);
        expect(await blazeToken.symbol()).to.equal(tokenSymbol);
    });

    it("Owner can mint tokens to other addresses", async () => {
        await blazeToken.mint(address1.address, ethers.utils.parseUnits("100000000", 18));
        expect(await blazeToken.balanceOf(address1.address))
            .to.equal(ethers.utils.parseUnits("100000000", 18));
    });
});
