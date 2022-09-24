const { expect } = require("chai");
const { ethers } = require("hardhat");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { BigNumber } = require("ethers");
const impersonateAccount = require("../utils/impersonateAccount");
const addresses = require("../utils/addresses");

let tokenInstance;
let tokenContract;
let owner, account1, account2;

describe("AnimaNFT", () => {
  beforeEach(async () => {
		if (network.name === "hardhat") {
      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [addresses.myAddress],
      });
      await network.provider.send("hardhat_setBalance", [
        addresses.myAddress,
        parseEther("8.0").toHexString(), // for some reason it only works with small amounts
      ]);
    }

    [owner, account1, account2, account3] = await ethers.getSigners();
    tokenInstance = await ethers.getContractFactory("AnimaNFT");
    tokenContract = await tokenInstance.deploy(
			["BCT", "NCT", "USDC", "WETH", "WMATIC"],
      [
        addresses.bct,
        addresses.nct,
        addresses.usdc,
        addresses.weth,
        addresses.wmatic,
      ]
		);
		await tokenContract.deployed();

		await tokenContract.toggleSaleActive();
  });
  describe("when mint", function () {
    it("mint NFT with swap tokens", async () => {
			const maticToSend = await tokenContract.estimateTokenToSwap(addresses.nct, ethers.utils.parseEther('1000'));
      await tokenContract
          .connect(account1)
          .mint(
						1,
						addresses.wmatic,
						maticToSend
					);
			const ownerOfNFT = await tokenContract.ownerOf(1);
			expect(ownerOfNFT).to.be.equal(account1.address);
			const depositedNCT = await tokenContract.deposits(1);
			expect(depositedNCT).to.be.equal(ethers.utils.parseEther('800'));
    });
  });
	describe("burn NFT", function() {
		it("burn NFT with withdraw deposit", async () => {
			await tokenContract.connect(account1).withdrawBurn(1);

			const depositedNFT = await tokenContract.deposits(1);
			expect(depositedNFT).to.be.equal(ethers.constants.Zero);
		});
	})
  describe("can update internal values", () => {
		it("set sale active by owner", async () => {
			await tokenContract.connect(owner).setSaleActive();
			const isSaleActive = await tokenContract.isSaleActive();
			expect(isSaleActive).to.be.equal(true);
		});
		it("pause sale by owner", async () => {
			await tokenContract.connect(owner).pauseSale();
			const isSaleActive = await tokenContract.isSaleActive();
			expect(isSaleActive).to.be.equal(false);
		});
		it("cannot set current mint limit if caller is not owner", async () => {
			await expectRevert(
				tokenContract.connect(account1).setSaleActive(),
				"Ownable: caller is not the owner"
			)
		});
  });
});